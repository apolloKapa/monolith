.pragma library

// True when item sits inside a view that can scroll (a Flickable / ListView / GridView with more
// content than room). Controls that react to the wheel (sliders, number boxes) pass the wheel on
// there, so scrolling a page never gets stuck on them or changes their value by accident.
function inScrollingView(item) {
    for (let p = item ? item.parent : null; p; p = p.parent) {
        if (p.contentY === undefined || p.flickableDirection === undefined) continue;
        if (p.interactive === false || p.visible === false) continue;
        const tall = p.contentHeight + (p.topMargin || 0) + (p.bottomMargin || 0) > p.height + 1;
        const wide = p.contentWidth + (p.leftMargin || 0) + (p.rightMargin || 0) > p.width + 1;
        if (tall || wide) return true;
    }
    return false;
}
