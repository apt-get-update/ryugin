import QtQuick

Page {
    id: page
    property string artistId
    property string name
    property var albums: []
    title: name
    Component.onCompleted: Api.getArtist(artistId, function (n, l) { if (!page) return; if (n) page.name = n; page.albums = l; })
    Row {
        spacing: 10
        TextButton { icon: "play"; text: "Play all"; primary: true; onClicked: page.playAll(false) }
        TextButton { icon: "shuffle"; text: "Shuffle"; onClicked: page.playAll(true) }
    }
    AlbumGrid { albums: page.albums }

    // Every track of every album, in album order.
    function playAll(shuffled) {
        const all = [];
        let left = albums.length;
        const ordered = new Array(albums.length);
        albums.forEach(function (a, i) {
            Api.getAlbum(a.id, function (x, tracks) {
                ordered[i] = tracks;
                if (--left === 0) {
                    for (const t of ordered) for (const s of t) all.push(s);
                    shuffled ? Player.shuffle(all) : Player.play(all, 0);
                }
            });
        });
    }
}
