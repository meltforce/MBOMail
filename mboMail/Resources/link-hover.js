(function() {
    if (window._mboLinkHoverInstalled) return;
    window._mboLinkHoverInstalled = true;

    function postHover(url) {
        window.webkit.messageHandlers.mbomail.postMessage({
            type: 'linkHover',
            url: url
        });
    }

    // Listen on the main document
    document.addEventListener('mouseover', function(e) {
        var link = e.target.closest('a[href]');
        if (link) postHover(link.href);
    }, true);
    document.addEventListener('mouseout', function(e) {
        var link = e.target.closest('a[href]');
        if (link) postHover('');
    }, true);

    // Inject hover listeners into iframes (mail detail frames)
    function injectIntoIframe(iframe) {
        try {
            var doc = iframe.contentDocument;
            if (!doc || doc._mboHoverInjected) return;
            doc._mboHoverInjected = true;
            doc.addEventListener('mouseover', function(e) {
                var link = e.target.closest('a[href]');
                if (link) postHover(link.href);
            }, true);
            doc.addEventListener('mouseout', function(e) {
                var link = e.target.closest('a[href]');
                if (link) postHover('');
            }, true);
        } catch(e) {}
    }

    // Inject into existing iframes
    document.querySelectorAll('iframe').forEach(function(f) {
        if (f.contentDocument) injectIntoIframe(f);
        f.addEventListener('load', function() { injectIntoIframe(f); });
    });

    // Watch for new iframes being added
    var obs = new MutationObserver(function(mutations) {
        mutations.forEach(function(m) {
            m.addedNodes.forEach(function(n) {
                if (n.tagName === 'IFRAME') {
                    if (n.contentDocument) injectIntoIframe(n);
                    n.addEventListener('load', function() { injectIntoIframe(n); });
                }
                if (n.querySelectorAll) {
                    n.querySelectorAll('iframe').forEach(function(f) {
                        if (f.contentDocument) injectIntoIframe(f);
                        f.addEventListener('load', function() { injectIntoIframe(f); });
                    });
                }
            });
        });
    });
    obs.observe(document.body, { childList: true, subtree: true });
})();
