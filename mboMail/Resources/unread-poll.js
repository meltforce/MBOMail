(function() {
    var nodes = document.querySelectorAll('.folder-node');
    var count = 0;
    for (var i = 0; i < nodes.length; i++) {
        var text = nodes[i].textContent || '';
        if (text.indexOf('Posteingang') !== -1 || text.indexOf('Inbox') !== -1) {
            var counter = nodes[i].querySelector('.folder-counter');
            if (counter) count = parseInt(counter.textContent, 10) || 0;
            break;
        }
    }
    var newest = document.querySelector('.list-item.unread');
    var subject = '';
    var from = '';
    if (newest) {
        var subEl = newest.querySelector('.subject');
        var fromEl = newest.querySelector('.from');
        if (subEl) subject = subEl.textContent.trim();
        if (fromEl) from = fromEl.textContent.trim();
    }
    window.webkit.messageHandlers.mbomail.postMessage({ type: 'unreadCount', count: count, subject: subject, from: from });
})();
