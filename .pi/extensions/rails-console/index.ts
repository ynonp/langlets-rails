/**
 * Rails Console Extension
 *
 * Provides the AI with persistent access to a Rails console (`./bin/rails c`).
 * The console runs as a background process, maintaining variable state across
 * multiple eval calls. This replaces the need for one-off `rails runner` scripts.
 *
 * Tools:
 *   rails_console_start  - Boot the Rails console (loads Rails env, may take 10-30s)
 *   rails_console_eval   - Evaluate Ruby code in the running console
 *   rails_console_close  - Shut down the console process
 *
 * The console preserves state: variables, classes, modules defined in one eval
 * are available in subsequent calls.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { spawn, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";
import { createInterface, type Interface } from "node:readline";

// ── Types ───────────────────────────────────────────────────────────────────

interface EvalResponse {
  status: "ok" | "error" | "ready";
  result?: string;
  output?: string | null;
  result_class?: string;
  error_class?: string;
  message?: string;
  backtrace?: string[];
  phase?: string;
}

interface PendingEval {
  resolve: (value: EvalResponse) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

// ── State ───────────────────────────────────────────────────────────────────

let consoleProcess: ChildProcess | null = null;
let rl: Interface | null = null;
let evalQueue: PendingEval[] = [];
let isReady = false;
const BOOT_TIMEOUT_MS = 90_000; // Rails can be very slow to boot
const EVAL_TIMEOUT_MS = 30_000; // Individual eval timeout

// ── Helpers ─────────────────────────────────────────────────────────────────

function killConsole(): void {
  if (consoleProcess && !consoleProcess.killed) {
    try {
      // Signal the Ruby bridge to exit cleanly
      consoleProcess.stdin?.write("exit\n__END__\n");
    } catch {
      // stdin may already be closed
    }
    setTimeout(() => {
      if (consoleProcess && !consoleProcess.killed) {
        consoleProcess.kill("SIGTERM");
        setTimeout(() => {
          if (consoleProcess && !consoleProcess.killed) {
            consoleProcess.kill("SIGKILL");
          }
        }, 3000);
      }
    }, 2000);
  }
  rejectAllPending(new Error("Console process terminated"));
  rl?.close();
  rl = null;
  consoleProcess = null;
  isReady = false;
}

function rejectAllPending(err: Error): void {
  const queue = evalQueue;
  evalQueue = [];
  for (const pending of queue) {
    clearTimeout(pending.timer);
    pending.reject(err);
  }
}

/**
 * Start reading lines from the child process stdout.
 * All JSON responses are routed to the eval queue — there's no separate
 * boot phase handling. The boot waiter also pushes into the queue.
 */
function startLineReader(): void {
  if (!consoleProcess?.stdout) return;

  rl = createInterface({ input: consoleProcess.stdout });
  rl.on("line", (line: string) => {
    try {
      const response: EvalResponse = JSON.parse(line);

      // Route to the next pending eval (or boot waiter)
      if (evalQueue.length > 0) {
        const pending = evalQueue.shift()!;
        clearTimeout(pending.timer);
        pending.resolve(response);
      }
    } catch {
      // Not JSON — Rails boot noise, log to stderr
      process.stderr.write(`[rails-console] ${line}\n`);
    }
  });
}

// ── Extension ───────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // Clean up on shutdown
  pi.on("session_shutdown", async () => {
    killConsole();
  });

  // ── rails_console_start ───────────────────────────────────────────────

  pi.registerTool({
    name: "rails_console_start",
    label: "Rails Console Start",
    description:
      "Start a persistent Rails console process. This loads the full Rails environment " +
      "(models, libraries, DB connection) and may take 15-30 seconds. Call this once " +
      "before using rails_console_eval. The console keeps variables and state across evals.",
    parameters: Type.Object({}),
    promptSnippet: "Start (or check status of) the persistent Rails console",
    promptGuidelines: [
      "Use rails_console_start once at the beginning of a Rails task, then use rails_console_eval " +
        "for each Ruby expression. Do NOT use rails runner scripts — the console preserves state.",
    ],

    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      // Already running?
      if (consoleProcess && !consoleProcess.killed && isReady) {
        return {
          content: [
            {
              type: "text",
              text: "Rails console is already running and ready for evals.",
            },
          ],
          details: { running: true, pid: consoleProcess.pid },
        };
      }

      // Clean up any stale process
      if (consoleProcess) killConsole();

      const bridgeScript = resolve(__dirname, "console_bridge.rb");
      const cwd = ctx.cwd;

      consoleProcess = spawn("bundle", ["exec", "ruby", bridgeScript, cwd], {
        cwd,
        stdio: ["pipe", "pipe", "pipe"],
        env: { ...process.env },
      });

      startLineReader();

      // Log stderr for debugging
      consoleProcess.stderr?.on("data", (data: Buffer) => {
        process.stderr.write(`[rails-console] ${data.toString()}`);
      });

      // If process dies unexpectedly, clean up
      consoleProcess.on("exit", (code) => {
        rl?.close();
        rl = null;
        isReady = false;
        if (consoleProcess) {
          rejectAllPending(
            new Error(`Console process exited with code ${code}`),
          );
        }
        consoleProcess = null;
      });

      // Wait for the boot response via the queue (same mechanism as evals)
      return new Promise((resolveExec) => {
        const bootTimer = setTimeout(() => {
          resolveExec({
            content: [
              {
                type: "text",
                text:
                  "Rails console failed to start within timeout. " +
                  "Check that `./bin/rails c` works manually and that bundle exec is available.",
              },
            ],
            details: { running: false, error: "boot_timeout" },
          });
        }, BOOT_TIMEOUT_MS);

        // Push a boot waiter into the same queue used by evals
        evalQueue.push({
          resolve: (response: EvalResponse) => {
            clearTimeout(bootTimer);

            if (response.status === "ready") {
              isReady = true;
              pi.appendEntry("rails-console-status", {
                running: true,
                pid: consoleProcess?.pid,
              });
              resolveExec({
                content: [
                  {
                    type: "text",
                    text:
                      "Rails console started successfully. The full Rails environment is loaded. " +
                      "You can now use rails_console_eval to execute Ruby code. " +
                      "Variables, classes, and state persist across calls.",
                  },
                ],
                details: { running: true, pid: consoleProcess?.pid },
              });
            } else if (response.status === "error" && response.phase === "boot") {
              // Boot failed — shown as an error
              isReady = false;
              resolveExec({
                content: [
                  {
                    type: "text",
                    text: `Rails console failed to boot: ${response.message}`,
                  },
                ],
                details: { running: false, error: "boot_failed", message: response.message },
              });
            } else {
              // Unexpected response during boot
              resolveExec({
                content: [
                  {
                    type: "text",
                    text: `Unexpected response during Rails boot: ${JSON.stringify(response)}`,
                  },
                ],
                details: { running: false, error: "unexpected_boot_response" },
              });
            }
          },
          reject: (err: Error) => {
            clearTimeout(bootTimer);
            resolveExec({
              content: [
                {
                  type: "text",
                  text: `Rails console failed to start: ${err.message}`,
                },
              ],
              details: { running: false, error: "boot_rejected", message: err.message },
            });
          },
          timer: bootTimer,
        });
      });
    },
  });

  // ── rails_console_eval ────────────────────────────────────────────────

  pi.registerTool({
    name: "rails_console_eval",
    label: "Rails Console Eval",
    description:
      "Evaluate Ruby code in the running Rails console. " +
      "Variables, classes, modules, and all state persist across calls. " +
      "The code runs in the full Rails environment — use ActiveRecord models, " +
      "Rails helpers, etc. directly. " +
      "IMPORTANT: Use this instead of writing temp scripts or using rails runner. " +
      "The console preserves state so you can define a variable in one call and " +
      "use it in the next. " +
      "Tip: For inspecting large datasets, use `.limit(5).pluck(:id, :name)` " +
      "or `.first(3).attributes` to keep output manageable.",
    parameters: Type.Object({
      code: Type.String({
        description:
          "Ruby code to evaluate. Multi-line is fine — separate statements with newlines. " +
          "Use .inspect, .to_s, pp, or puts for output. The return value of the last " +
          "expression is automatically inspected and returned.",
      }),
    }),
    promptSnippet: "Evaluate Ruby code in the persistent Rails console",
    promptGuidelines: [
      "Use rails_console_eval for all Rails interactions instead of writing and running scripts. " +
        "Define variables once and reuse them across calls. " +
        "For model queries, use ActiveRecord directly: User.where(...), Post.find_by(...), etc.",
    ],

    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      if (!consoleProcess || consoleProcess.killed || !isReady) {
        return {
          content: [
            {
              type: "text",
              text: "Rails console is not running. Call rails_console_start first.",
            },
          ],
          details: { running: false },
        };
      }

      const code = params.code.trim();
      if (!code) {
        return {
          content: [
            { type: "text", text: "No code provided. Please provide Ruby code to evaluate." },
          ],
          details: { status: "empty" },
        };
      }

      return new Promise((resolveExec, rejectExec) => {
        const timer = setTimeout(() => {
          resolveExec({
            content: [
              {
                type: "text",
                text: `Rails console eval timed out after ${EVAL_TIMEOUT_MS / 1000}s. The code might be stuck in an infinite loop or a long-running query.`,
              },
            ],
            details: { status: "timeout" },
          });
        }, EVAL_TIMEOUT_MS);

        evalQueue.push({
          resolve: (response: EvalResponse) => {
            clearTimeout(timer);

            if (response.status === "error") {
              const parts = [`**Error: ${response.error_class}**: ${response.message}`];
              if (response.backtrace?.length) {
                parts.push(
                  "Backtrace:\n" +
                    response.backtrace.map((l) => `  ${l}`).join("\n"),
                );
              }
              resolveExec({
                content: [{ type: "text", text: parts.join("\n") }],
                details: {
                  status: "error",
                  error_class: response.error_class,
                  message: response.message,
                },
              });
              return;
            }

            let text = "";
            if (response.output) {
              text += `Output:\n${response.output.trimEnd()}\n`;
            }
            text += `=> ${response.result ?? "nil"}`;
            if (response.result_class && response.result_class !== "NilClass") {
              text += `  (${response.result_class})`;
            }

            resolveExec({
              content: [{ type: "text", text }],
              details: {
                status: "ok",
                result: response.result,
                output: response.output,
                result_class: response.result_class,
              },
            });
          },
          reject: (err: Error) => {
            clearTimeout(timer);
            rejectExec(err);
          },
          timer,
        });

        // Send code to the Ruby bridge
        try {
          consoleProcess!.stdin!.write(code + "\n__END__\n");
        } catch (err) {
          clearTimeout(timer);
          // Remove our entry from the queue
          evalQueue = evalQueue.filter((e) => e.timer !== timer);
          resolveExec({
            content: [
              {
                type: "text",
                text:
                  "Failed to send code to Rails console: " +
                  `${err instanceof Error ? err.message : String(err)}. ` +
                  "The console may have crashed. Try rails_console_start to restart.",
              },
            ],
            details: { status: "write_error" },
          });
        }
      });
    },

    // ── Custom rendering ─────────────────────────────────────────────

    renderCall(args, theme, _context) {
      const code = args.code as string;
      const firstLine = code.split("\n")[0] ?? "";
      const preview =
        firstLine.length > 60 ? firstLine.slice(0, 57) + "..." : firstLine;

      return new Text(
        theme.fg("toolTitle", theme.bold("rails")) +
          " " +
          theme.fg("muted", preview),
        0,
        0,
      );
    },

    renderResult(result, { expanded }, theme, _context) {
      const details = result.details as Record<string, unknown> | undefined;
      const text = result.content?.[0];
      const rawText =
        text?.type === "text" ? text.text : JSON.stringify(result.content);

      if (details?.status === "error") {
        const firstErrorLine = rawText.split("\n")[0] ?? rawText;
        return new Text(
          expanded ? rawText : theme.fg("error", firstErrorLine),
          0,
          0,
        );
      }

      if (details?.status === "timeout") {
        return new Text(theme.fg("warning", rawText), 0, 0);
      }

      return new Text(
        expanded
          ? rawText
          : theme.fg("success", "✓ ") + theme.fg("muted", rawText),
        0,
        0,
      );
    },
  });

  // ── rails_console_close ───────────────────────────────────────────────

  pi.registerTool({
    name: "rails_console_close",
    label: "Rails Console Close",
    description: "Close the running Rails console process to free resources.",
    parameters: Type.Object({}),

    async execute() {
      if (!consoleProcess) {
        return {
          content: [{ type: "text", text: "No Rails console running." }],
          details: { running: false },
        };
      }

      killConsole();
      return {
        content: [
          {
            type: "text",
            text: "Rails console closed. Call rails_console_start to restart.",
          },
        ],
        details: { running: false },
      };
    },
  });
}
