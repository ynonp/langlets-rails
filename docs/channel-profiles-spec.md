# Channel Profiles

## Status

**Superseded historical proposal.** This document describes the original
Channel-profile design and is not the maintained production behavior. Channel
profiles and `/channels/:slug` were subsequently removed; course cards do not
show Channel attribution, and invitation acceptance returns to the homepage.
See the *Channels* section of [docs/architecture.md](architecture.md) for the
shipped behavior.

## Goal

Move Langlets from one globally curated library toward a tool people use to
create and share their own language-learning content.

Every account initially has one private default Channel. The Channel is the
user's publishing identity: courses they import are automatically saved there.
The data model supports multiple Channels per user later, although the initial
UI exposes only the default Channel.

Channels have exactly three visibility modes:

- `public`: visible to every signed-in user. Public Channel content is included
  in Home and Library without requiring a subscription. Only an administrator
  may create a public Channel or change a Channel to public.
- `shared`: invite-only. A user sees the Channel and its content only after
  accepting an invitation and subscribing.
- `private`: visible only to its owner and administrators. It cannot be followed
  or invited to.

There are no system Channels. Curated site-wide content uses ordinary public
Channels owned and managed by an administrator.

## Product Vocabulary

| Concept | Responsibility |
|---|---|
| **User** | Authentication, billing, settings, and account administration |
| **Channel** | A publishing identity and its visibility boundary |
| **Playlist** | A user's organization or ordered sequence of courses |
| **Channel item** | Content made available through a Channel |
| **Channel invitation** | An invitation for an email address/user to join a shared Channel |
| **Subscription** | An accepted membership in, or explicit follow of, a Channel |
| **Enrollment** | A user's personal learning state for a course |
| **Course** | A shared, AI-generated learning artifact |

A Playlist answers, "Which courses belong together?" A Channel answers, "What
does this identity contribute, and who may receive it?"

Channels and Playlists remain separate. Publishing Playlists is outside the
initial release.

## Initial Release

1. Every user has exactly one default Channel in the UI.
2. A regular user cannot create or delete Channels.
3. Default Channels are private.
4. A regular user may change their default Channel between private and shared.
5. Only an administrator may create a public Channel or change any Channel to
   public.
6. Selecting a shared Channel exposes an Invite action. The owner enters one or
   more email addresses and the system sends each invite both by email and,
   when the address belongs to an account, through an in-app notification.
7. Accepting an invitation creates a subscription. Only then does the invitee
   see the shared Channel's content in the Channel page, Home, and Library.
8. Home and Library show content from the set union of:
   - all public Channels; and
   - Channels the current user subscribes to.
9. Every successfully imported course is idempotently saved to the importing
   user's default Channel.
10. Users cannot remove imported courses from their default Channel.
11. Channels are language-neutral.
12. Historical data is backfilled with SQL only.
13. All user-facing text is stored in `config/locales` locale files. Views,
    controllers, mailers, jobs, and JavaScript must not introduce hard-coded
    interface copy.

Multiple user-managed Channels, publishing controls, removing Channel items,
publishing existing Library courses, and publishing Playlists are out of scope.

## Core Domain Decisions

### Channel is an identity

Subscriptions, invitations, and items reference Channels rather than owners:

```text
User -> one default Channel today
User -> many Channels later
```

A personal or curated Channel always belongs to a User. Do not use nullable or
polymorphic ownership; administrator-owned public Channels replace the former
system-Channel concept.

### Visibility defines discovery and access

| Visibility | Discoverable by | Content readable by | Subscription path |
|---|---|---|---|
| `public` | Every signed-in user | Every signed-in user | Not required for Home/Library inclusion |
| `shared` | Owner, admins, accepted subscribers, and invitees with a valid pending invitation | Owner, admins, and accepted subscribers | Accept an invitation |
| `private` | Owner and admins | Owner and admins | None |

Public is openly readable to signed-in users; it no longer means
"followable but subscriber-only." A public Channel is included automatically in
Home and Library. If the UI offers an explicit Follow action for public
Channels, that subscription must not be required for visibility or inclusion
and should only support optional preferences such as notifications.

A shared Channel is invite-only. Knowing its slug is not authorization. Before
acceptance, an invitee may see only the invitation acceptance screen and the
minimum Channel identity necessary to make that decision; they may not see its
course list.

Signed-out visitors are sent through authentication while preserving the
return URL. After authentication, authorization is evaluated again.

### Visibility transitions

- `private -> shared`: owner or admin; enables invitations.
- `shared -> private`: owner or admin; revoke all pending invitations and delete
  all non-owner subscriptions in the same transaction.
- `shared/private -> public`: admin only.
- `public -> shared/private`: admin only. Moving to private revokes invitations
  and subscriptions; moving to shared keeps existing subscriptions as accepted
  members unless the admin explicitly removes them.

These transitions must take effect immediately in direct Channel access, Home,
and Library.

### Course membership is automatic and permanent initially

When an `ImportRequest` completes successfully, insert the resolved shared
Course into the importing user's default Channel. The operation is idempotent
for retries, deduplicated courses, and multiple users importing the same Course.

`courses.user_id` remains historical creator information, not Channel
membership authority.

### Following is not enrollment

Channel visibility or subscription changes discovery only. It never creates an
`Enrollment`. Starting or explicitly saving a Course continues to use the
existing Enrollment flow.

### Channels are language-neutral

Do not add `language_id` to Channels, subscriptions, or invitations. Home and
Library may apply the current learning-language query as a presentation filter.

## Proposed Data Model

### `channels`

| Column | Type | Notes |
|---|---|---|
| `user_id` | bigint, not null | Owner, including admin owner of public Channels |
| `name` | string, not null | User-editable display name |
| `slug` | string, not null | Stable route identifier |
| `visibility` | integer, not null | `private`, `shared`, or `public`; default `private` |
| `default` | boolean, not null | Default publishing Channel for its owner |
| timestamps | | |

Constraints and indexes:

- Unique index on `slug`.
- Partial unique index on `user_id` where `default = true`.
- Index on `[visibility, created_at]`.
- Foreign key to Users.

Do not add a general unique index on `user_id`; future multiple Channels must
remain possible. `User#provision_default_channel!` transactionally and
idempotently creates the private default Channel.

Suggested domain API:

```ruby
class User < ApplicationRecord
  has_many :channels, dependent: :destroy
  has_one :default_channel, -> { where(default: true) }, class_name: "Channel"

  def provision_default_channel!
    # Find or create the private default Channel safely under concurrency.
  end
end

class Channel < ApplicationRecord
  belongs_to :user
  has_many :channel_items, dependent: :destroy
  has_many :channel_subscriptions, dependent: :destroy
  has_many :channel_invitations, dependent: :destroy

  def publish!(course, published_at: Time.zone.now)
    # Idempotently create the ChannelItem.
  end

  def change_visibility!(visibility, actor:)
    # Authorize and apply visibility-transition cleanup transactionally.
  end

  def invite!(email:, inviter:)
    # Validate shared visibility and idempotently create/send an invitation.
  end
end
```

Domain rules belong in models/services rather than controllers.

### `channel_items`

| Column | Type | Notes |
|---|---|---|
| `channel_id` | bigint, not null | Destination Channel |
| `course_id` | bigint, not null | Shared Course |
| `published_at` | datetime, not null | Home/Library chronology |
| timestamps | | |

Use a unique index on `[channel_id, course_id]`, a feed index on
`[channel_id, published_at]`, and foreign keys. Use `published_at`, not
`courses.created_at`, because an old shared Course may be new to a Channel.

### `channel_subscriptions`

| Column | Type | Notes |
|---|---|---|
| `channel_id` | bigint, not null | Followed/joined Channel |
| `user_id` | bigint, not null | Subscriber |
| timestamps | | |

Use a unique index on `[channel_id, user_id]`, an index on
`[user_id, created_at]`, and foreign keys.

For shared Channels, a row may be created only by accepting a valid invitation
(or by an explicit admin membership action). Owners do not need to subscribe to
their own Channels.

### `channel_invitations`

| Column | Type | Notes |
|---|---|---|
| `channel_id` | bigint, not null | Shared Channel |
| `inviter_id` | bigint, not null | Owner/admin who sent it |
| `invitee_id` | bigint, nullable | Matching account, when one exists |
| `email` | string, not null | Normalized destination address |
| `token_digest` | string, not null | Digest of single-use email token |
| `status` | integer, not null | `pending`, `accepted`, `declined`, `revoked`, `expired` |
| `expires_at` | datetime, not null | Expiration boundary |
| `accepted_at` | datetime, nullable | Acceptance audit timestamp |
| timestamps | | |

Indexes and constraints:

- Foreign keys to Channel and inviter/invitee Users.
- Unique token digest.
- At most one pending invitation per normalized
  `[channel_id, email]` (partial unique index).
- Lookup indexes on `[invitee_id, status]` and `[email, status]`.

Store normalized email for matching, but never store the raw invitation token.
Invitation acceptance must lock or atomically update the pending row, verify
expiry and authenticated email ownership, create the subscription
idempotently, mark the invitation accepted, and create the in-app acceptance
state in one transaction.

Sending email and in-app delivery should be queued only after commit. Retries
must not create duplicate pending invitations or duplicate subscriptions.

## Routes and User Flows

### Profile management

The signed-in Profile page shows the default Channel's name and visibility.
Regular users may select Private or Shared. Admins may also select Public and
may create/manage admin-owned public Channels through an admin-only surface.

When Shared is selected, show:

- an Invite action;
- an email entry field that accepts multiple addresses;
- pending invitations with revoke/resend actions; and
- accepted subscribers with a remove action.

All labels, validation messages, flash messages, accessibility labels, email
subjects/bodies, and in-app notification copy use locale keys under
`config/locales`.

The update endpoint is scoped through the authorized Channel; a browser-supplied
id never grants access. Names need not be globally unique, and renaming does not
change the slug.

### Channel page

Use `/channels/:slug`.

- Owner/admin: see identity, content, and permitted management actions.
- Private, anyone else: 404.
- Shared, accepted subscriber: see content and an Unsubscribe action.
- Shared, valid pending invitee: see identity and Accept/Decline actions, but no
  content before acceptance.
- Shared, anyone else: 404.
- Public, signed-in: see identity and content without subscribing.
- Signed-out: authenticate and preserve the return URL, then re-authorize.

Unsubscribing from a shared Channel immediately removes it and its content from
the user's Channel page, Home, and Library. Rejoining requires a new invitation.

### Invitation delivery and acceptance

`POST /channels/:slug/invitations` accepts one or more email addresses and is
available only for shared Channels to their owner/admin. Each valid address
receives:

1. An email containing an expiring, single-use acceptance link.
2. An in-app invitation when the normalized address belongs to a User.

Users also get an in-app invitations list reachable from the normal signed-in
navigation. Accept and Decline work from either delivery path and converge on
the same domain operation. An email invite to a user without an account sends
them through sign-up/sign-in, preserves the token, and verifies that the
authenticated account owns the invited email before acceptance.

Do not disclose whether an entered email already has a Langlets account.

### Home and Library

Both surfaces use the same visibility scope:

```text
visible_channel_ids =
  public Channel ids
  UNION
  current user's subscribed Channel ids
  UNION
  current user's owned Channel ids
```

The owned-Channel term ensures users continue to see their own private content.
The required audience rule for other people's content remains exactly
subscriptions union public Channels.

Home preserves its learning-state sections and adds a bounded newest-first
Channel updates section. Library lists the available Channel content using its
existing grouping/pagination conventions. Both:

- join through ChannelItems;
- apply current Course readiness and learning-language rules;
- order Channel contributions by `channel_items.published_at`;
- include Channel identity on cards;
- avoid duplicate rows caused by a public Channel that is also subscribed;
- preserve two distinct contributions when two Channels publish the same
  Course;
- batch-load localized Course data and avoid N+1 queries; and
- never create Enrollments while reading.

Put the shared scope/query object below both controllers so Home and Library
cannot drift into different authorization behavior.

### Import completion

Extend `ImportRequest#complete!` transactionally so successful completion
ensures the existing Enrollment and a ChannelItem in the importing user's
default Channel. Use an upsert/find-or-create backed by the unique index.
Failure to provision or publish must roll back rather than report an incomplete
success.

## SQL-Only Data Backfill

Use set-based, idempotent PostgreSQL statements in a data migration. Do not
instantiate application models.

1. Insert one private default Channel for every existing User:
   - localized UI copy must not come from this stored name;
   - use a neutral persisted name such as `My Channel`;
   - use a collision-safe immutable slug such as `channel-<user_id>`;
   - set timestamps explicitly.
2. Insert ChannelItems by joining successful ready `import_requests` through
   `user_id` and `course_id` to each user's default Channel.
3. Deduplicate `[channel_id, course_id]` and use the earliest successful request
   timestamp approximation as `published_at`.
4. Do not create public Channels, invitations, or subscriptions in the generic
   backfill.
5. Verify zero missing defaults, duplicate defaults, duplicate items, and
   successful imports without corresponding items.

## Authorization

Centralize rules in `Ability` and reusable scopes:

- Owners/admins can read and manage their authorized Channels.
- Regular users can change their default Channel only between private/shared.
- Only admins can create public Channels or transition a Channel to/from public.
- Public content is readable by every signed-in user.
- Shared content is readable only by owner/admin/accepted subscribers.
- Only a shared Channel owner/admin may invite, resend, revoke, or remove
  members.
- Only the invited user may accept or decline an invitation.
- Private and unauthorized shared URLs return 404.
- No user-facing action removes ChannelItems in the initial release.

Apply the same rules to direct URLs, invitation endpoints, Home, Library,
mail-link redirects, and background jobs—not only visible buttons.

## Localization

All user-facing text is stored in `config/locales` YAML files and accessed with
I18n keys. This includes:

- Channel visibility names and descriptions.
- Profile, Channel, Home, Library, and invitation UI.
- Form placeholders, errors, flash messages, empty states, confirmations, and
  accessibility text.
- Invitation email subject/body and in-app invitation/acceptance copy.
- Background-job failure text that can surface to users.

Persisted user-entered Channel names and invited email addresses are data, not
translatable copy. Enum values remain stable internal identifiers and are
translated only at presentation time. Add locale coverage tests for every
supported locale and do not use English fallbacks as a substitute for missing
keys.

## Delivery Plan

### Phase 1: Schema and domain models

1. Add Channels, ChannelItems, ChannelSubscriptions, and ChannelInvitations with
   foreign keys, indexes, enums, defaults, and check constraints.
2. Add associations and idempotent domain operations for provisioning,
   publishing, visibility transitions, invitations, acceptance, decline,
   revoke, unsubscribe, and member removal.
3. Test concurrency, duplicate prevention, token expiry, email normalization,
   and every allowed/forbidden visibility transition.

### Phase 2: SQL backfill and provisioning

1. Implement and verify the SQL-only backfill.
2. Provision a private default Channel for new accounts.
3. Test concurrent provisioning and historical shared-course imports.

### Phase 3: Import integration

1. Publish every completed import to the requester's default Channel.
2. Test new, reused, concurrent, retried, and failed imports.

### Phase 4: Localized profile and admin management

1. Add default Channel profile editing for name and private/shared visibility.
2. Add admin-only creation and management of public Channels.
3. Add all copy to locale files and test authorization and missing translations.
4. Preserve CSS safe areas. If adding Stimulus controllers, use `data-action`
   and run `./bin/rails stimulus:manifest:update`.

### Phase 5: Shared invitations

1. Add multi-email invitation UI, pending/accepted member management, and
   in-app invitations list.
2. Add email and in-app delivery after commit.
3. Add token-preserving authentication and atomic accept/decline/revoke flows.
4. Test account-existence privacy, wrong-email acceptance, expiry, replay,
   resend, removal, and visibility changes with pending/accepted invitations.

### Phase 6: Channel page

1. Add `/channels/:slug` with private/shared/public authorization behavior.
2. Render localized identity, invite, membership, and content states.
3. Test signed-out return paths and direct URL access for every role/state.

### Phase 7: Home and Library

1. Implement one shared query for owned Channels plus the union of public and
   subscribed Channels.
2. Integrate it into both Home and Library with language/readiness filters.
3. Deduplicate public-plus-subscribed membership without collapsing the same
   Course published by different Channels.
4. Inspect query plans and test pagination, empty states, revocation, privacy
   transitions, mixed languages, and N+1 behavior.

### Phase 8: Rollout and documentation

1. Add operational metrics for invitation delivery/acceptance and visibility
   invariant checks.
2. Roll out query changes behind a feature flag if production data volume
   requires it.
3. Update privacy/support documentation for email invitations and public
   identities.
4. Update `docs/architecture.md` after implementation to reflect production.

## Acceptance Criteria

- Every existing and new user has one private default Channel.
- There are no system Channels or system-specific columns/branches.
- Visibility is exactly private, shared, or public.
- Only admins can create public Channels or make a Channel public.
- Public Channel content appears in every signed-in user's Home and Library
  without a required subscription.
- Shared Channels are undiscoverable and unreadable without an invitation;
  accepted invitees become subscribers and then see their content.
- Invites are delivered by email and in-app when an account matches.
- Invite acceptance is expiring, single-use, email-bound, atomic, and
  idempotent.
- Private Channels remain owner/admin-only.
- Home and Library show the union of public and subscribed Channel content,
  plus the current user's own private content.
- Following/joining never creates Course Enrollments.
- Imports are idempotently added to the importing user's default Channel.
- Channels remain language-neutral.
- All user-facing text is stored in `config/locales`.
- SQL backfill is set-based and restartable.
- Direct URLs and query scopes enforce the same authorization as the UI.
- Channel queries avoid N+1 loading and are tested with production-like plans.
- `docs/architecture.md` is updated when the feature ships.
