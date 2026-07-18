let strings

function translations() {
  if (strings !== undefined) return strings

  const element = document.getElementById("i18n-strings")
  if (!element) return (strings = {})

  try {
    return (strings = JSON.parse(element.textContent))
  } catch (_error) {
    return (strings = {})
  }
}

export function t(key, params = {}) {
  const value = key.split(".").reduce((object, part) => object?.[part], translations())
  if (typeof value !== "string") return key

  return value.replace(/%\{([^}]+)\}/g, (placeholder, name) =>
    Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : placeholder
  )
}
