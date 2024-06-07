- 75 bytes per tick, 4,500 bytes per second.
- Add 2 for each line for packet header
- coord is 2 byte number

`GROUP_RESET 1`
`DRAW White horizontal bar 8 bytes`
`DRAW company name 4 + 1 + 2 bytes (pos + dbIdx + "%s")`
`DB company name 2 + ~12 bytes`
`DRAW money 4 + 1 + 3 bytes (pos + dbIdx + "%%s")`
`DB money 2 + ~4 bytes`
`GROUP_ENABLE 1`

- Group 1 setup used 59 bytes
- Group 1 update all db values uses 20 bytes


- - Packet types

`FULL_RESET`
- Resets ALL state.

`GROUP_RESET (group_id : 1 bytes)`
- Sets as current group, removes all draw cmds.
`GROUP_SET (group_id : 1 bytes, draw_idx : 1 bytes)`
- Sets current group and draw index.
`GROUP_ENABLE (group_id : 1 bytes)`
- Makes group drawn to screen.
`GROUP_DISABLE (group_id : 1 bytes)`
- Stops group from being drawn to screen.

`DB_SET_STRING (db_idx : 1 bytes, db_idxy : 1 bytes, str : varying bytes)`
`DB_SET_NUMBER (db_idx : 1 bytes, db_idxy : 1 bytes, zsr_double : 0-8 bytes)`
- `zsr_double` is a big endian double, with trailing zeros removed.

`DRAW_COLOR (r : 1 bytes, g : 1 bytes, b : 1 bytes, a : 0-1 bytes)`
`DRAW_RECT (x : 2 bytes, y : 2 bytes, w : 2 bytes, h : 2 bytes)`
`DRAW_RECTF (x : 2 bytes, y : 2 bytes, w : 2 bytes, h : 2 bytes)`
`DRAW_CIRCLE (x : 2 bytes, y : 2 bytes, r : 2 bytes)`
`DRAW_CIRCLEF (x : 2 bytes, y : 2 bytes, r : 2 bytes)`
`DRAW_TRIANGLE (x1 : 2 bytes, y1 : 2 bytes, x2 : 2 bytes, y2 : 2 bytes, x3 : 2 bytes, y3 : 2 bytes)`
`DRAW_TRIANGLEF (x1 : 2 bytes, y1 : 2 bytes, x2 : 2 bytes, y2 : 2 bytes, x3 : 2 bytes, y3 : 2 bytes)`
`DRAW_LINE (x1 : 2 bytes, y1 : 2 bytes, x2 : 2 bytes, y2 : 2 bytes)`
`DRAW_TEXT (x : 2 bytes, y : 2 bytes, db_idx : 1 bytes, fmt : varying bytes)`
- If `db_idx` is not 0, `fmt` is a format string, otherwise a normal string.
`DRAW_TEXTBOX (x : 2 bytes, y : 2 bytes, w : 2 bytes, h : 2 bytes, db_idx : 1 bytes, fmt : varying bytes, h_align : 1 bytes, v_align : 1 bytes)`
- If `db_idx` is not 0, `fmt` is a format string, otherwise a normal string.
`DRAW_MAP (x : 2 bytes, y : 2 bytes, zoom : TODO bytes)`
- TODO: Map colors
