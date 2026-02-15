(function() {
    // Clean up previous observers/timers to prevent duplicates on re-injection
    if (window._mboUnreadInterval) clearInterval(window._mboUnreadInterval);
    if (window._mboUnreadObserver) window._mboUnreadObserver.disconnect();
    if (window._mboDebounceTimer) clearTimeout(window._mboDebounceTimer);

    function getUnreadInfo() {
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
        // Extract newest unread email's subject and sender from the mail list
        var newest = document.querySelector('.list-item.unread');
        var subject = '';
        var from = '';
        if (newest) {
            var subEl = newest.querySelector('.subject');
            var fromEl = newest.querySelector('.from');
            if (subEl) subject = subEl.textContent.trim();
            if (fromEl) from = fromEl.textContent.trim();
        }
        window.webkit.messageHandlers.mbomail.postMessage({
            type: 'unreadCount',
            count: count,
            subject: subject,
            from: from
        });
    }

    // Debounced wrapper: waits for DOM mutations to settle before reading.
    // Prevents rapid-fire postMessage calls when multiple emails arrive at once.
    function debouncedGetUnreadInfo() {
        if (window._mboDebounceTimer) clearTimeout(window._mboDebounceTimer);
        window._mboDebounceTimer = setTimeout(function() {
            window._mboDebounceTimer = null;
            getUnreadInfo();
        }, 1500);
    }

    setTimeout(getUnreadInfo, 2000);

    var folderTree = document.querySelector('.tree-container, .folder-tree');
    if (folderTree) {
        window._mboUnreadObserver = new MutationObserver(function() { debouncedGetUnreadInfo(); });
        window._mboUnreadObserver.observe(folderTree, { childList: true, subtree: true, characterData: true });
    }

    window._mboUnreadInterval = setInterval(getUnreadInfo, 30000);
})();
