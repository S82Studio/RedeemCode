(function () {
    'use strict';

    let cfg = null;
    const queue = [];
    const QUEUE_MAX = 200;
    let overflowReported = false;
    const _unknownWarned = Object.create(null);

    const hasOwn = Object.prototype.hasOwnProperty;

    function flushIfReady() {
        if (!cfg) return;
        while (queue.length) {
            const e = queue.shift();
            emit(e.cat, e.sev, e.msg);
        }
    }

    function emit(cat, sev, msg) {
        if (!cfg) {
            if (queue.length < QUEUE_MAX) {
                queue.push({ cat: cat, sev: sev, msg: msg });
            } else if (!overflowReported) {
                overflowReported = true;
                queue.push({
                    cat: 'ERROR', sev: 'warn',
                    msg: 'debug queue overflow (>' + QUEUE_MAX +
                         '), dropping further pre-config logs'
                });
            }
            return;
        }
        if (!cfg.enabled) return;
        if (!hasOwn.call(cfg.categories, cat)) {
            if (!_unknownWarned[cat]) {
                _unknownWarned[cat] = true;
                console.error('[NUI][DEBUG] unknown category: ' +
                              cat + ' (call site bug)');
            }
            return;
        }
        if (!cfg.categories[cat]) return;
        const sevTag = sev === 'warn' ? '[WARN] '
                     : sev === 'err'  ? '[ERR]  '
                     : '';
        const line = '[NUI][' + cat + '] ' + sevTag + msg;
        if (sev === 'err')       console.error(line);
        else if (sev === 'warn') console.warn(line);
        else                     console.log(line);
    }

    window.Dbg = {
        log:  function (cat, msg) { emit(cat, 'info', String(msg)); },
        warn: function (cat, msg) { emit(cat, 'warn', String(msg)); },
        err:  function (msg)      { emit('ERROR', 'err', String(msg)); }
    };

    window.addEventListener('message', function (e) {
        if (e.data && e.data.action === 'debug:config') {
            cfg = e.data.payload;
            flushIfReady();
        }
    });
})();
