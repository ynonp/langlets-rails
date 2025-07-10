import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["switch"]; // Optional: if you want to change switch appearance

  connect() {
    this.applyTheme();
    window.addEventListener('storage', (event) => {
      if (event.key === 'theme') {
        this.applyTheme();
      }
    });
  }

  applyTheme() {
    const theme = this.currentTheme;
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
    this.updateSwitchAppearance(theme); // Optional
    window.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme } }));
  }

  toggle() {
    const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('theme', newTheme);
    this.applyTheme();
  }

  get currentTheme() {
    let theme = localStorage.getItem('theme');
    if (!theme) {
      theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return theme;
  }

  // Optional: if your switch needs to visually change
  updateSwitchAppearance(theme) {
    if (this.hasSwitchTarget) {
      // Example: Add logic to change icon or text based on theme
      // this.switchTarget.innerHTML = theme === 'dark' ? 'Light Mode' : 'Dark Mode';
    }
  }
}
