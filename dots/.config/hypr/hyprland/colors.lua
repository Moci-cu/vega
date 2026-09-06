hl.config({
    general = {
        col = {
            active_border   = "rgba(44464fFF)",
            inactive_border = "rgba(1a1b20D9)",
        },
    },
    misc = {
        background_color = "rgba(121318FF)",
    },
})

hl.window_rule({ -- not sure how to syntax "pin 1"
    match        = { pin = 1 },
    border_color = "rgba(afc6ffAA) rgba(afc6ff77)",
})
