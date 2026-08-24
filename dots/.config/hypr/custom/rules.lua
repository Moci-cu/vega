hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^(Manga Reader)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^(Manga Reader)$" }, center = true })

-- Subtle translucency for content-heavy daily apps.
hl.window_rule({
    match = { class = "^(kitty)$" },
    opacity = "0.88 override 0.84 override 1.0 override",
    no_blur = true
})
