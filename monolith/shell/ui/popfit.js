.pragma library

// Where a drop-down list opens so it stays inside what you can see and click: the list
// (or page) it is in, else its window. Settings only takes clicks on its own card, so a
// list hanging past the card's edge showed but couldn't be clicked. It opens below the
// field when it fits (or when there's more room below), above it otherwise, and is cut to
// the room there (the list scrolls).

// the first clipping ancestor big enough to hold a list (a scrolling page), else the window
function bounds(item) {
    let p = item ? item.parent : null, last = null;
    while (p) {
        if (p.clip && p.height >= 200) return p;
        last = p;
        p = p.parent;
    }
    return last;
}

// {y, h, up}: y relative to the field, h = the list's height (at most `want`)
function place(item, want, gap) {
    const b = bounds(item);
    if (!b) return { y: item.height + gap, h: want, up: false };
    const pos = item.mapToItem(b, 0, 0);
    const below = b.height - (pos.y + item.height) - gap - 8;
    const above = pos.y - gap - 8;
    if (want <= below || below >= above)
        return { y: item.height + gap, h: Math.max(60, Math.min(want, below)), up: false };
    const h = Math.max(60, Math.min(want, above));
    return { y: -gap - h, h: h, up: true };
}
