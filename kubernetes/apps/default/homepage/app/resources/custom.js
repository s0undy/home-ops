// The greeting widget only renders the static string from widgets.yaml, so swap in a
// time-of-day greeting client side. homepage injects this with next/script's default
// afterInteractive strategy, and React re-renders the header on every SWR
// revalidation, so an observer re-applies the text whenever the node is replaced.
(() => {
  const SELECTOR = ".information-widget-greeting span";

  const greeting = () => {
    const h = new Date().getHours();
    if (h < 5) return "Still up?";
    if (h < 12) return "Good morning.";
    if (h < 18) return "Good afternoon.";
    return "Good evening.";
  };

  const apply = () => {
    const el = document.querySelector(SELECTOR);
    const text = greeting();
    if (el && el.textContent !== text) el.textContent = text;
  };

  apply();
  new MutationObserver(apply).observe(document.body, { childList: true, subtree: true });
  setInterval(apply, 60_000); // cross a boundary without needing a reload
})();
