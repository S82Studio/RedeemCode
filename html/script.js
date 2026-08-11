(function () {
    'use strict';

    const Dbg = window.Dbg || { log: function () {}, warn: function () {}, err: function () {} };

    let locale = {};
    let activeCodes = [];
    let historyData = [];
    let rewardItems = [];
    let allItems = [];
    let onlinePlayers = [];
    let moneyTypes = [];
    let targetCitizens = [];
    let imageTemplate = '';
    let currentRewardType = 'money';
    let editingCode = null;
    let expiryPicker = null;

    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => document.querySelectorAll(sel);

    const dom = {
        redeemPanel:    $('#redeem-panel'),
        adminPanel:     $('#admin-panel'),
        codeInput:      $('#code-input'),
        redeemBtn:      $('#redeem-btn'),
        statusMsg:      $('#status-msg'),
        rewardsList:    $('#rewards-list'),
        redeemCloseBtn: $('#redeem-close-btn'),
        adminCloseBtn:  $('#admin-close-btn'),
        toastContainer: $('#toast-container'),
        adminCodeInput:    $('#admin-code-input'),
        generateCodeBtn:   $('#generate-code-btn'),
        moneySection:      $('#money-section'),
        itemsSection:      $('#items-section'),
        moneyAccounts:     $('#money-accounts'),
        itemNameInput:     $('#item-name-input'),
        itemSearchDropdown:$('#item-search-dropdown'),
        itemAmountInput:   $('#item-amount-input'),
        addItemBtn:        $('#add-item-btn'),
        rewardItemsList:   $('#reward-items-list'),
        maxUsesInput:      $('#max-uses-input'),
        expiryInput:       $('#expiry-input'),
        privateToggle:     $('#private-toggle'),
        privateTarget:     $('#private-target'),
        targetCitizenId:   $('#target-citizenid-input'),
        addTargetBtn:      $('#add-target-btn'),
        targetList:        $('#target-list'),
        createCodeBtn:     $('#create-code-btn'),
        cancelEditBtn:     $('#cancel-edit-btn'),
        activeCodesBody:   $('#active-codes-body'),
        activeCodesEmpty:  $('#active-codes-empty'),
        activeCodesSearch: $('#active-codes-search'),
        historyBody:       $('#history-body'),
        historyEmpty:      $('#history-empty'),
        historySearch:     $('#history-search'),
        clearHistoryBtn:   $('#clear-history-btn'),
        viewItemsListBtn:  $('#view-items-list-btn'),
        itemsModal:        $('#items-modal'),
        itemsModalCloseBtn:$('#items-modal-close-btn'),
        modalItemSearch:   $('#modal-item-search'),
        modalItemSort:     $('#modal-item-sort'),
        modalItemsGrid:    $('#modal-items-grid'),
        pickPlayerBtn:       $('#pick-player-btn'),
        playersModal:        $('#players-modal'),
        playersModalCloseBtn:$('#players-modal-close-btn'),
        modalPlayerSearch:   $('#modal-player-search'),
        modalPlayersList:    $('#modal-players-list'),
    };

    if (typeof flatpickr !== 'undefined' && dom.expiryInput) {
        expiryPicker = flatpickr(dom.expiryInput, {
            enableTime: true,
            dateFormat: "Y-m-d H:i",
            time_24hr: true,
            disableMobile: true
        });
    }

    function applyLocale() {
        $$('[data-locale]').forEach((el) => {
            const key = el.getAttribute('data-locale');
            if (locale[key]) el.textContent = locale[key];
        });
        $$('[data-locale-placeholder]').forEach((el) => {
            const key = el.getAttribute('data-locale-placeholder');
            if (locale[key]) el.placeholder = locale[key];
        });
        $$('[data-locale-title]').forEach((el) => {
            const key = el.getAttribute('data-locale-title');
            if (locale[key]) el.title = locale[key];
        });
        if (expiryPicker && typeof flatpickr !== 'undefined' && flatpickr.l10ns) {
            const lang = (locale.locale_code || 'en-US').slice(0, 2);
            expiryPicker.set('locale', flatpickr.l10ns[lang] || flatpickr.l10ns.default);
        }
    }

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        if (data.action !== 'debug:config') {
            Dbg.log('UI', 'message: ' + data.action);
        }

        switch (data.action) {
            case 'openRedeem':
                openRedeem(data);
                break;
            case 'openAdmin':
                openAdmin(data);
                break;
            case 'closeUI':
                closeUI();
                break;
            case 'redeemResult':
                handleRedeemResult(data);
                break;
            case 'codeCreated':
                handleCodeCreated(data);
                break;
            case 'codeDeleted':
                handleCodeDeleted(data);
                break;
            case 'historyCleared':
                handleHistoryCleared(data);
                break;
            case 'refreshCodes':
                handleRefreshCodes(data);
                break;
            case 'onlinePlayers':
                handleOnlinePlayers(data);
                break;
            case 'toast':
                showToast(data.type || 'info', data.message || '');
                break;
        }
    });

    function openRedeem(data) {
        if (data.locale) {
            locale = data.locale;
            applyLocale();
        }
        if (data.imageTemplate) {
            imageTemplate = data.imageTemplate;
        }
        clearRedeemState();
        dom.redeemPanel.classList.remove('hidden');
        setTimeout(() => dom.codeInput.focus(), 100);
        Dbg.log('UI', 'redeem panel opened');
    }

    function openAdmin(data) {
        if (data.locale) {
            locale = data.locale;
            applyLocale();
        }
        if (data.codes) activeCodes = data.codes;
        if (data.history) historyData = data.history;
        if (data.items) allItems = data.items;
        if (data.moneyTypes) moneyTypes = data.moneyTypes;
        if (data.imageTemplate) imageTemplate = data.imageTemplate;
        rewardItems = [];
        targetCitizens = [];
        renderRewardItems();
        renderMoneyAccounts();
        renderTargets();
        renderActiveCodes();
        renderHistory();
        dom.adminPanel.classList.remove('hidden');
        Dbg.log('UI', 'admin panel opened: codes=' + activeCodes.length +
            ' history=' + historyData.length + ' items=' + allItems.length);
    }

    function closeUI() {
        dom.redeemPanel.classList.add('hidden');
        dom.adminPanel.classList.add('hidden');
        Dbg.log('UI', 'panel closed');
        postNUI('closeUI', {});
    }

    function clearRedeemState() {
        dom.codeInput.value = '';
        dom.statusMsg.className = 'status-msg';
        dom.statusMsg.textContent = '';
        dom.rewardsList.classList.add('hidden');
        dom.rewardsList.innerHTML = '';
        dom.redeemBtn.classList.remove('loading');
    }

    dom.redeemBtn.addEventListener('click', () => {
        const code = dom.codeInput.value.trim();
        if (!code) {
            shakeInput(dom.codeInput);
            return;
        }
        dom.redeemBtn.classList.add('loading');
        dom.statusMsg.className = 'status-msg';
        dom.statusMsg.textContent = '';
        dom.rewardsList.classList.add('hidden');
        Dbg.log('UI', 'redeem submit');
        postNUI('redeemCode', { code: code });
    });

    dom.codeInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            dom.redeemBtn.click();
        }
    });

    function handleRedeemResult(data) {
        Dbg.log('UI', 'redeem result: success=' + !!data.success);
        dom.redeemBtn.classList.remove('loading');
        const type = data.success ? 'success' : 'error';
        dom.statusMsg.className = `status-msg ${type} visible animate`;
        dom.statusMsg.textContent = data.message || '';

        if (data.success && data.rewards) {
            renderRewards(data.rewards);
        }

        if (!data.success) {
            shakeInput(dom.codeInput);
        }
    }

    function renderRewards(rewards) {
        dom.rewardsList.innerHTML = '';
        dom.rewardsList.classList.remove('hidden');

        const moneysArr = Array.isArray(rewards.moneys) ? rewards.moneys : [];
        if (moneysArr.length > 0) {
            moneysArr.forEach((m) => {
                if (m && m.amount > 0) {
                    dom.rewardsList.appendChild(createRewardEl(
                        'money',
                        'fa-dollar-sign',
                        moneyLabel(m.type, m.label) || locale.reward_money || 'Money',
                        '$' + formatNumber(m.amount)
                    ));
                }
            });
        } else if (rewards.money && rewards.money > 0) {
            dom.rewardsList.appendChild(createRewardEl(
                'money',
                'fa-dollar-sign',
                locale.reward_money || 'Money',
                '$' + formatNumber(rewards.money)
            ));
        }

        if (rewards.items) {
            const itemsArr = Array.isArray(rewards.items) ? rewards.items : Object.values(rewards.items);
            if (itemsArr.length > 0) {
                itemsArr.forEach((item) => {
                    if (item && typeof item === 'object') {
                        dom.rewardsList.appendChild(createRewardEl(
                            'item',
                            'fa-box-open',
                            item.label || item.name || item.item,
                            'x' + (item.amount || item.count || 1),
                            item.name || item.item,
                            item.image
                        ));
                    }
                });
            }
        }
    }

    function createRewardEl(type, icon, name, detail, technicalName, customImg) {
        const div = document.createElement('div');
        div.className = 'reward-item';
        
        let iconHtml = `<i class="fas ${icon}"></i>`;
        if (type === 'item' && technicalName) {
            const imgUrl = customImg || getItemImage(technicalName);
            if (imgUrl) {
                iconHtml = `<img src="${imgUrl}" class="reward-item-img" onerror="this.outerHTML='<i class=\\'fas ${icon}\\'></i>'">`;
            }
        }

        div.innerHTML = `
            <div class="reward-item-icon ${type}">
                ${iconHtml}
            </div>
            <div class="reward-item-info">
                <div class="reward-item-name">${escapeHtml(name)}</div>
                <div class="reward-item-detail">${escapeHtml(detail)}</div>
            </div>
        `;
        return div;
    }

    $$('.admin-tab-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
            $$('.admin-tab-btn').forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            const tab = btn.getAttribute('data-tab');
            $$('.admin-tab-content').forEach((c) => c.classList.add('hidden'));
            $(`#tab-${tab}`).classList.remove('hidden');
        });
    });

    $$('.reward-type-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
            $$('.reward-type-btn').forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            currentRewardType = btn.getAttribute('data-type');
            updateRewardSections();
        });
    });

    function updateRewardSections() {
        switch (currentRewardType) {
            case 'money':
                dom.moneySection.classList.remove('hidden');
                dom.itemsSection.classList.add('hidden');
                break;
            case 'item':
                dom.moneySection.classList.add('hidden');
                dom.itemsSection.classList.remove('hidden');
                break;
            case 'both':
                dom.moneySection.classList.remove('hidden');
                dom.itemsSection.classList.remove('hidden');
                break;
        }
    }

    function moneyLabel(id, fallback) {
        return locale['money_type_' + id] || fallback || id;
    }

    function renderMoneyAccounts() {
        if (!dom.moneyAccounts) return;
        dom.moneyAccounts.innerHTML = '';

        if (!moneyTypes || moneyTypes.length === 0) {
            const note = document.createElement('div');
            note.className = 'money-accounts-empty';
            note.textContent = locale.admin_no_money_accounts || 'No money accounts available.';
            dom.moneyAccounts.appendChild(note);
            return;
        }

        moneyTypes.forEach((t) => {
            const row = document.createElement('div');
            row.className = 'money-account-row';
            const iconClass = (typeof t.icon === 'string' && t.icon) ? t.icon : 'fa-solid fa-coins';
            row.innerHTML = `
                <i class="${escapeAttr(iconClass)}"></i>
                <span class="money-account-label">${escapeHtml(moneyLabel(t.id, t.label))}</span>
                <input type="number" class="field field-num money-account-input" data-type="${escapeAttr(t.id)}" min="0" placeholder="0" />
            `;
            dom.moneyAccounts.appendChild(row);
        });
    }

    function getMoneysFromInputs() {
        const out = [];
        if (!dom.moneyAccounts) return out;
        dom.moneyAccounts.querySelectorAll('.money-account-input').forEach((inp) => {
            const type = inp.getAttribute('data-type');
            const amount = parseInt(inp.value, 10) || 0;
            if (type && amount > 0) {
                out.push({ type: type, amount: amount });
            }
        });
        return out;
    }

    function setMoneyInputs(list) {
        if (!dom.moneyAccounts) return;
        const byType = {};
        if (Array.isArray(list)) {
            list.forEach((m) => {
                if (m && m.type) byType[m.type] = m.amount || 0;
            });
        }
        dom.moneyAccounts.querySelectorAll('.money-account-input').forEach((inp) => {
            const type = inp.getAttribute('data-type');
            inp.value = (byType[type] && byType[type] > 0) ? byType[type] : '';
        });
    }

    dom.privateToggle.addEventListener('change', () => {
        if (dom.privateToggle.checked) {
            dom.privateTarget.classList.remove('hidden');
            setTimeout(() => dom.targetCitizenId.focus(), 50);
        } else {
            dom.privateTarget.classList.add('hidden');
            dom.targetCitizenId.value = '';
            targetCitizens = [];
            renderTargets();
        }
    });

    function addTarget(citizenid, name) {
        const id = (citizenid || '').trim();
        if (!id) return false;
        if (targetCitizens.some((t) => t.citizenid === id)) return false;
        targetCitizens.push({ citizenid: id, name: name || null });
        renderTargets();
        return true;
    }

    function removeTarget(citizenid) {
        targetCitizens = targetCitizens.filter((t) => t.citizenid !== citizenid);
        renderTargets();
    }

    function isTarget(citizenid) {
        return targetCitizens.some((t) => t.citizenid === citizenid);
    }

    function renderTargets() {
        if (!dom.targetList) return;
        dom.targetList.innerHTML = '';
        targetCitizens.forEach((t) => {
            const chip = document.createElement('div');
            chip.className = 'target-chip';
            const nameHtml = t.name ? `<span class="target-chip-name">${escapeHtml(t.name)}</span>` : '';
            chip.innerHTML = `
                ${nameHtml}
                <code class="target-chip-id">${escapeHtml(t.citizenid)}</code>
                <button class="target-chip-remove" type="button" title="${escapeHtml(locale.title_remove || 'Remove')}"><i class="fas fa-xmark"></i></button>
            `;
            chip.querySelector('.target-chip-remove').addEventListener('click', () => removeTarget(t.citizenid));
            dom.targetList.appendChild(chip);
        });
    }

    function addTargetFromInput() {
        const id = dom.targetCitizenId.value.trim();
        if (!id) { shakeInput(dom.targetCitizenId); return; }
        addTarget(id, null);
        dom.targetCitizenId.value = '';
        dom.targetCitizenId.focus();
    }

    if (dom.addTargetBtn) dom.addTargetBtn.addEventListener('click', addTargetFromInput);
    dom.targetCitizenId.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            addTargetFromInput();
        }
    });

    let selectedDropdownIndex = -1;
    let filteredSearchItems = [];

    function getItemImage(itemName) {
        if (!itemName) return null;
        if (allItems && allItems.length > 0) {
            const lowerName = itemName.toLowerCase();
            const found = allItems.find(item => item.name && item.name.toLowerCase() === lowerName);
            if (found && found.image) {
                return found.image;
            }
        }
        if (!imageTemplate || imageTemplate === '') return null;
        return imageTemplate.replace('%s', itemName.toLowerCase());
    }

    function renderSearchDropdown() {
        dom.itemSearchDropdown.innerHTML = '';
        if (filteredSearchItems.length === 0) {
            dom.itemSearchDropdown.classList.add('hidden');
            detachDropdownReposition();
            return;
        }

        filteredSearchItems.forEach((item, idx) => {
            const div = document.createElement('div');
            div.className = 'search-dropdown-item';
            if (idx === selectedDropdownIndex) {
                div.classList.add('selected');
            }
            
            const imgUrl = getItemImage(item.name);
            const imgHtml = imgUrl 
                ? `<img class="dropdown-item-img" src="${imgUrl}" onerror="this.style.display='none'">` 
                : `<i class="fas fa-box-open" style="margin-right: 8px; opacity: 0.5;"></i>`;

            div.innerHTML = `
                <div style="display: flex; align-items: center;">
                    ${imgHtml}
                    <span class="item-lbl">${escapeHtml(item.label || item.name)}</span>
                </div>
                <span class="item-name-code">${escapeHtml(item.name)}</span>
            `;

            div.addEventListener('click', () => {
                selectSearchItem(item.name);
            });

            dom.itemSearchDropdown.appendChild(div);
        });

        dom.itemSearchDropdown.classList.remove('hidden');
        positionSearchDropdown();
        attachDropdownReposition();

        const selectedEl = dom.itemSearchDropdown.querySelector('.search-dropdown-item.selected');
        if (selectedEl) {
            selectedEl.scrollIntoView({ block: 'nearest' });
        }
    }

    function selectSearchItem(name) {
        dom.itemNameInput.value = name;
        hideSearchDropdown();
        dom.itemAmountInput.focus();
    }

    function hideSearchDropdown() {
        dom.itemSearchDropdown.classList.add('hidden');
        dom.itemSearchDropdown.innerHTML = '';
        detachDropdownReposition();
        const s = dom.itemSearchDropdown.style;
        s.top = s.bottom = s.left = s.width = s.maxHeight = s.visibility = '';
        selectedDropdownIndex = -1;
        filteredSearchItems = [];
    }

    let ddReposition = null;

    function positionSearchDropdown() {
        const input = dom.itemNameInput;
        const dd = dom.itemSearchDropdown;
        if (!input || !dd || dd.classList.contains('hidden')) return;

        const r = input.getBoundingClientRect();
        const scroller = input.closest('.admin-tab-content');
        if (scroller) {
            const sr = scroller.getBoundingClientRect();
            if (r.bottom <= sr.top + 2 || r.top >= sr.bottom - 2) {
                dd.style.visibility = 'hidden';
                return;
            }
        }
        dd.style.visibility = '';

        const gap = 6;
        const cap = 240;
        const vh = window.innerHeight;
        const spaceBelow = vh - r.bottom - gap - 8;
        const spaceAbove = r.top - gap - 8;

        dd.style.left = r.left + 'px';
        dd.style.width = r.width + 'px';
        dd.style.right = 'auto';

        if (spaceBelow >= Math.min(cap, 160) || spaceBelow >= spaceAbove) {
            dd.style.top = (r.bottom + gap) + 'px';
            dd.style.bottom = 'auto';
            dd.style.maxHeight = Math.max(96, Math.min(cap, spaceBelow)) + 'px';
        } else {
            dd.style.top = 'auto';
            dd.style.bottom = (vh - r.top + gap) + 'px';
            dd.style.maxHeight = Math.max(96, Math.min(cap, spaceAbove)) + 'px';
        }
    }

    function attachDropdownReposition() {
        if (ddReposition) return;
        ddReposition = function () { positionSearchDropdown(); };
        window.addEventListener('scroll', ddReposition, true);
        window.addEventListener('resize', ddReposition);
    }

    function detachDropdownReposition() {
        if (!ddReposition) return;
        window.removeEventListener('scroll', ddReposition, true);
        window.removeEventListener('resize', ddReposition);
        ddReposition = null;
    }

    function updateSearchFilter() {
        const query = dom.itemNameInput.value.trim().toLowerCase();
        if (!allItems || allItems.length === 0) {
            filteredSearchItems = [];
            selectedDropdownIndex = -1;
            renderSearchDropdown();
            return;
        }

        if (query === '') {
            filteredSearchItems = [...allItems];
        } else {
            filteredSearchItems = allItems.filter(item => {
                const name = (item.name || '').toLowerCase();
                const label = (item.label || '').toLowerCase();
                return name.includes(query) || label.includes(query);
            });
        }

        if (filteredSearchItems.length > 80) {
            filteredSearchItems = filteredSearchItems.slice(0, 80);
        }

        selectedDropdownIndex = Math.min(selectedDropdownIndex, filteredSearchItems.length - 1);
        if (filteredSearchItems.length > 0 && selectedDropdownIndex < 0) {
            selectedDropdownIndex = 0;
        }

        renderSearchDropdown();
    }

    dom.addItemBtn.addEventListener('click', addRewardItem);

    dom.itemNameInput.addEventListener('input', () => {
        selectedDropdownIndex = 0;
        updateSearchFilter();
    });

    dom.itemNameInput.addEventListener('focus', () => {
        selectedDropdownIndex = 0;
        updateSearchFilter();
    });

    dom.itemNameInput.addEventListener('blur', () => {
        setTimeout(() => {
            hideSearchDropdown();
        }, 150);
    });

    dom.itemNameInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            if (!dom.itemSearchDropdown.classList.contains('hidden') && filteredSearchItems.length > 0 && selectedDropdownIndex >= 0) {
                e.preventDefault();
                selectSearchItem(filteredSearchItems[selectedDropdownIndex].name);
            } else {
                e.preventDefault();
                addRewardItem();
            }
        } else if (e.key === 'ArrowDown') {
            if (!dom.itemSearchDropdown.classList.contains('hidden')) {
                e.preventDefault();
                selectedDropdownIndex = (selectedDropdownIndex + 1) % filteredSearchItems.length;
                renderSearchDropdown();
            }
        } else if (e.key === 'ArrowUp') {
            if (!dom.itemSearchDropdown.classList.contains('hidden')) {
                e.preventDefault();
                selectedDropdownIndex = (selectedDropdownIndex - 1 + filteredSearchItems.length) % filteredSearchItems.length;
                renderSearchDropdown();
            }
        } else if (e.key === 'Escape') {
            if (!dom.itemSearchDropdown.classList.contains('hidden')) {
                e.preventDefault();
                hideSearchDropdown();
            }
        }
    });

    function addRewardItem() {
        const name = dom.itemNameInput.value.trim();
        const amount = parseInt(dom.itemAmountInput.value) || 1;

        if (!name) {
            shakeInput(dom.itemNameInput);
            return;
        }

        rewardItems.push({ name: name, amount: amount });
        dom.itemNameInput.value = '';
        dom.itemAmountInput.value = '1';
        dom.itemNameInput.focus();
        renderRewardItems();
    }

    function removeRewardItem(index) {
        rewardItems.splice(index, 1);
        renderRewardItems();
    }

    function renderRewardItems() {
        dom.rewardItemsList.innerHTML = '';
        rewardItems.forEach((item, idx) => {
            const row = document.createElement('div');
            row.className = 'reward-item-row';
            
            const imgUrl = getItemImage(item.name);
            const imgHtml = imgUrl
                ? `<img class="row-item-img" src="${imgUrl}" onerror="this.style.display='none'">`
                : `<i class="fas fa-box-open" style="margin-right: 6px; opacity: 0.5;"></i>`;

            row.innerHTML = `
                <div class="reward-item-row-info">
                    ${imgHtml}
                    <span>${escapeHtml(item.name)}</span>
                    <span class="item-qty">x${item.amount}</span>
                </div>
                <button class="remove-item-btn" data-index="${idx}" title="${escapeHtml(locale.title_remove || 'Remove')}">
                    <i class="fas fa-trash-can"></i>
                </button>
            `;
            row.querySelector('.remove-item-btn').addEventListener('click', () => {
                removeRewardItem(idx);
            });
            dom.rewardItemsList.appendChild(row);
        });
    }

    function openItemsModal() {
        dom.modalItemSearch.value = '';
        if (dom.modalItemSort) dom.modalItemSort.value = 'label-asc';
        filterModalItems();
        dom.itemsModal.classList.remove('hidden');
        setTimeout(() => dom.modalItemSearch.focus(), 150);
    }

    function closeItemsModal() {
        dom.itemsModal.classList.add('hidden');
    }

    function renderModalItems(itemsList) {
        dom.modalItemsGrid.innerHTML = '';
        
        if (!itemsList || itemsList.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'empty-state';
            empty.style.gridColumn = '1 / -1';
            empty.innerHTML = `
                <i class="fas fa-magnifying-glass" style="font-size: 2rem;"></i>
                <p>${escapeHtml(locale.modal_no_items || 'No matching items found')}</p>
            `;
            dom.modalItemsGrid.appendChild(empty);
            return;
        }

        itemsList.forEach((item) => {
            const card = document.createElement('div');
            card.className = 'modal-item-card';
            
            const imgUrl = getItemImage(item.name);
            const imgHtml = imgUrl
                ? `<img src="${imgUrl}" onerror="this.outerHTML='<i class=\\'fas fa-box-open\\' style=\\'font-size: 1.5rem; opacity: 0.4;\\'></i>'">`
                : `<i class="fas fa-box-open" style="font-size: 1.5rem; opacity: 0.4;"></i>`;

            card.innerHTML = `
                <div class="modal-item-img-wrapper">
                    ${imgHtml}
                </div>
                <div class="modal-item-label">${escapeHtml(item.label || item.name)}</div>
                <div class="modal-item-name">${escapeHtml(item.name)}</div>
            `;

            card.addEventListener('click', () => {
                dom.itemNameInput.value = item.name;
                closeItemsModal();
                dom.itemAmountInput.focus();
            });

            dom.modalItemsGrid.appendChild(card);
        });
    }

    function filterModalItems() {
        const query = dom.modalItemSearch.value.trim().toLowerCase();
        let filtered = [...allItems];

        if (query !== '') {
            filtered = allItems.filter(item => {
                const name = (item.name || '').toLowerCase();
                const label = (item.label || '').toLowerCase();
                return name.includes(query) || label.includes(query);
            });
        }

        const sortVal = dom.modalItemSort ? dom.modalItemSort.value : 'label-asc';
        
        filtered.sort((a, b) => {
            let valA = '';
            let valB = '';
            
            if (sortVal.startsWith('name')) {
                valA = (a.name || '').toLowerCase();
                valB = (b.name || '').toLowerCase();
            } else {
                valA = (a.label || a.name || '').toLowerCase();
                valB = (b.label || b.name || '').toLowerCase();
            }
            
            if (sortVal.endsWith('asc')) {
                return valA.localeCompare(valB);
            } else {
                return valB.localeCompare(valA);
            }
        });

        renderModalItems(filtered);
    }

    dom.viewItemsListBtn.addEventListener('click', openItemsModal);
    dom.itemsModalCloseBtn.addEventListener('click', closeItemsModal);
    dom.modalItemSearch.addEventListener('input', filterModalItems);
    if (dom.modalItemSort) dom.modalItemSort.addEventListener('change', filterModalItems);
    if (dom.historySearch) dom.historySearch.addEventListener('input', filterHistoryLogs);
    if (dom.activeCodesSearch) dom.activeCodesSearch.addEventListener('input', filterActiveCodes);

    function openPlayersModal() {
        if (!dom.playersModal) return;
        dom.modalPlayerSearch.value = '';
        onlinePlayers = [];
        renderPlayersLoading();
        dom.playersModal.classList.remove('hidden');
        postNUI('getOnlinePlayers', {});
        setTimeout(() => dom.modalPlayerSearch.focus(), 150);
    }

    function closePlayersModal() {
        if (dom.playersModal) dom.playersModal.classList.add('hidden');
    }

    function handleOnlinePlayers(data) {
        onlinePlayers = Array.isArray(data.players) ? data.players : [];
        if (dom.playersModal && !dom.playersModal.classList.contains('hidden')) {
            filterPlayers();
        }
    }

    function renderPlayersLoading() {
        dom.modalPlayersList.innerHTML = '';
        const el = document.createElement('div');
        el.className = 'empty-state';
        el.innerHTML = `
            <i class="fas fa-circle-notch fa-spin"></i>
            <p>${escapeHtml(locale.modal_players_loading || 'Loading players...')}</p>
        `;
        dom.modalPlayersList.appendChild(el);
    }

    function renderPlayers(list) {
        dom.modalPlayersList.innerHTML = '';

        if (!list || list.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'empty-state';
            empty.innerHTML = `
                <i class="fas fa-user-slash"></i>
                <p>${escapeHtml(locale.modal_no_players || 'No online players found')}</p>
            `;
            dom.modalPlayersList.appendChild(empty);
            return;
        }

        list.forEach((p) => {
            const row = document.createElement('div');
            row.className = 'player-row';

            const first = p.firstname || '';
            const last = p.lastname || '';
            const charName = p.charName || `${first} ${last}`.trim() || '—';

            const steamNameHtml = p.steamName
                ? `<span class="player-steam-name"><i class="fas fa-gamepad"></i> ${escapeHtml(p.steamName)}</span>`
                : '';
            const steamHexHtml = p.steamHex
                ? `<span class="player-steam-hex" title="${escapeHtml(locale.title_copy_steam || 'Click to copy Steam HEX')}"><i class="fab fa-steam"></i> ${escapeHtml(p.steamHex)}<i class="fas fa-copy player-steam-copy"></i></span>`
                : '';

            row.innerHTML = `
                <div class="player-id-badge">${escapeHtml(String(p.source))}</div>
                <div class="player-info">
                    <div class="player-info-top">
                        <span class="player-char-name">${escapeHtml(charName)}</span>
                        <code class="player-cid">${escapeHtml(p.citizenid || '—')}</code>
                    </div>
                    <div class="player-info-meta">
                        ${steamNameHtml}
                        ${steamHexHtml}
                    </div>
                </div>
                <i class="fas fa-chevron-right player-pick-arrow"></i>
                <i class="fas fa-check player-pick-check"></i>
            `;

            if (p.citizenid && isTarget(p.citizenid)) row.classList.add('added');
            row.addEventListener('click', () => togglePlayerTarget(p, row));

            if (p.steamHex) {
                const hexEl = row.querySelector('.player-steam-hex');
                if (hexEl) {
                    hexEl.addEventListener('click', (e) => {
                        e.stopPropagation();
                        copyToClipboard(p.steamHex);
                        showToast('success', (locale.toast_steam_copied || 'Steam HEX copied:') + ' ' + p.steamHex);
                    });
                }
            }

            dom.modalPlayersList.appendChild(row);
        });
    }

    function togglePlayerTarget(p, row) {
        if (!p || !p.citizenid) {
            showToast('error', locale.player_no_cid || 'This player has no Citizen ID.');
            return;
        }
        if (isTarget(p.citizenid)) {
            removeTarget(p.citizenid);
            if (row) row.classList.remove('added');
        } else {
            addTarget(p.citizenid, p.charName || null);
            if (row) row.classList.add('added');
        }
    }

    function filterPlayers() {
        const query = dom.modalPlayerSearch.value.trim().toLowerCase();
        if (!query) {
            renderPlayers(onlinePlayers);
            return;
        }

        const filtered = onlinePlayers.filter((p) => {
            const source = String(p.source || '').toLowerCase();
            const cid = (p.citizenid || '').toLowerCase();
            const steamName = (p.steamName || '').toLowerCase();
            const steamHex = (p.steamHex || '').toLowerCase();
            const first = (p.firstname || '').toLowerCase();
            const last = (p.lastname || '').toLowerCase();
            const full = (p.charName || `${first} ${last}`).toLowerCase();

            return source.includes(query) ||
                   cid.includes(query) ||
                   steamName.includes(query) ||
                   steamHex.includes(query) ||
                   first.includes(query) ||
                   last.includes(query) ||
                   full.includes(query);
        });

        renderPlayers(filtered);
    }

    if (dom.pickPlayerBtn) dom.pickPlayerBtn.addEventListener('click', openPlayersModal);
    if (dom.playersModalCloseBtn) dom.playersModalCloseBtn.addEventListener('click', closePlayersModal);
    if (dom.modalPlayerSearch) dom.modalPlayerSearch.addEventListener('input', filterPlayers);

    const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    dom.generateCodeBtn.addEventListener('click', () => {
        const segments = [];
        for (let s = 0; s < 3; s++) {
            let seg = '';
            for (let c = 0; c < 4; c++) {
                seg += CODE_CHARS.charAt(Math.floor(Math.random() * CODE_CHARS.length));
            }
            segments.push(seg);
        }
        dom.adminCodeInput.value = segments.join('-');
    });

    dom.createCodeBtn.addEventListener('click', () => {
        const code = dom.adminCodeInput.value.trim();
        if (!code) {
            shakeInput(dom.adminCodeInput);
            return;
        }

        const payload = {
            code: code,
            rewardType: currentRewardType,
            moneys: [],
            items: [],
            maxUses: parseInt(dom.maxUsesInput.value) || 0,
            expiry: dom.expiryInput.value || null,
            isPrivate: dom.privateToggle.checked,
            targetCitizenids: dom.privateToggle.checked ? targetCitizens.map((t) => t.citizenid) : [],
        };

        if (currentRewardType === 'money' || currentRewardType === 'both') {
            payload.moneys = getMoneysFromInputs();
        }
        if (currentRewardType === 'item' || currentRewardType === 'both') {
            payload.items = [...rewardItems];
        }

        if ((payload.rewardType === 'money' || payload.rewardType === 'both') && payload.moneys.length === 0) {
            showToast('error', locale.admin_error_no_money || 'Please enter at least one money amount.');
            return;
        }
        if ((payload.rewardType === 'item' || payload.rewardType === 'both') && payload.items.length === 0) {
            showToast('error', locale.admin_error_no_items || 'Please add at least one item.');
            return;
        }
        if (payload.isPrivate && payload.targetCitizenids.length === 0) {
            showToast('error', locale.admin_error_no_targets || 'Add at least one target Citizen ID.');
            return;
        }

        if (editingCode) {
            Dbg.log('UI', 'admin update submit code=' + payload.code);
            postNUI('updateCode', payload);
        } else {
            Dbg.log('UI', 'admin create submit code=' + payload.code);
            postNUI('createCode', payload);
        }
    });

    dom.cancelEditBtn.addEventListener('click', cancelEdit);

    function handleCodeCreated(data) {
        showToast('success', data.message || locale.admin_code_created || 'Code saved successfully!');
        if (data.codes) activeCodes = data.codes;
        renderActiveCodes();
        cancelEdit();
    }

    function editCode(code) {
        editingCode = code.code;
        
        dom.adminCodeInput.value = code.code;
        dom.adminCodeInput.disabled = true;
        
        const tabBtn = $(`.reward-type-btn[data-type="${code.reward_type}"]`);
        if (tabBtn) tabBtn.click();
        
        setMoneyInputs(code.moneys || []);

        rewardItems = [];
        if (code.items) {
            const itemsArr = Array.isArray(code.items) ? code.items : Object.values(code.items);
            itemsArr.forEach(it => {
                if (it && typeof it === 'object') {
                    rewardItems.push({ name: it.name, amount: it.amount || 1 });
                }
            });
        }
        renderRewardItems();
        
        dom.maxUsesInput.value = code.max_uses || 0;
        
        if (expiryPicker) {
            if (code.expiry) {
                expiryPicker.setDate(code.expiry);
            } else {
                expiryPicker.clear();
            }
        } else {
            if (code.expiry) {
                dom.expiryInput.value = code.expiry.replace(' ', 'T').substring(0, 16);
            } else {
                dom.expiryInput.value = '';
            }
        }
        
        dom.privateToggle.checked = code.is_private;
        dom.targetCitizenId.value = '';
        if (code.is_private) {
            dom.privateTarget.classList.remove('hidden');
            targetCitizens = (Array.isArray(code.target_citizenids) ? code.target_citizenids : [])
                .filter((id) => typeof id === 'string' && id !== '')
                .map((id) => ({ citizenid: id, name: null }));
        } else {
            dom.privateTarget.classList.add('hidden');
            targetCitizens = [];
        }
        renderTargets();
        
        dom.createCodeBtn.querySelector('span').textContent = locale.admin_save_btn || 'Save Changes';
        dom.createCodeBtn.querySelector('i').className = 'fas fa-save';
        
        dom.cancelEditBtn.classList.remove('hidden');
        
        const createTabBtn = $(`.admin-tab-btn[data-tab="create"]`);
        if (createTabBtn) createTabBtn.click();
    }

    function cancelEdit() {
        editingCode = null;
        
        dom.adminCodeInput.value = '';
        dom.adminCodeInput.disabled = false;
        
        const defaultTypeBtn = $(`.reward-type-btn[data-type="money"]`);
        if (defaultTypeBtn) defaultTypeBtn.click();
        
        setMoneyInputs([]);
        rewardItems = [];
        renderRewardItems();
        dom.maxUsesInput.value = '0';
        if (expiryPicker) {
            expiryPicker.clear();
        } else {
            dom.expiryInput.value = '';
        }
        
        dom.privateToggle.checked = false;
        dom.privateTarget.classList.add('hidden');
        dom.targetCitizenId.value = '';
        targetCitizens = [];
        renderTargets();
        
        dom.createCodeBtn.querySelector('span').textContent = locale.admin_create_btn || 'Create Code';
        dom.createCodeBtn.querySelector('i').className = 'fas fa-wand-magic-sparkles';
        
        dom.cancelEditBtn.classList.add('hidden');
    }

    function deleteCode(code) {
        Dbg.log('UI', 'admin delete submit code=' + code);
        postNUI('deleteCode', { code: code });
    }

    function handleCodeDeleted(data) {
        showToast('info', data.message || locale.admin_code_deleted || 'Code deleted.');
        if (data.codes) activeCodes = data.codes;
        renderActiveCodes();
    }

    function handleHistoryCleared(data) {
        showToast('success', data.message || locale.admin_history_cleared || 'Redemption history cleared.');
        historyData = [];
        renderHistory();
    }

    function handleRefreshCodes(data) {
        if (data.codes) activeCodes = data.codes;
        if (data.history) historyData = data.history;
        renderActiveCodes();
        renderHistory();
    }

    function renderActiveCodes() {
        if (dom.activeCodesSearch) {
            dom.activeCodesSearch.value = '';
        }
        renderActiveCodesList(activeCodes);
    }

    function renderActiveCodesList(data) {
        dom.activeCodesBody.innerHTML = '';

        if (!data || data.length === 0) {
            dom.activeCodesEmpty.classList.remove('hidden');
            return;
        }

        dom.activeCodesEmpty.classList.add('hidden');

        data.forEach((c) => {
            const tr = document.createElement('tr');

            const typeBadge = getTypeBadge(c.reward_type);
            const rewardsText = getRewardsText(c);
            const usesText = c.max_uses === 0
                ? `${c.uses || 0} / ∞`
                : `${c.uses || 0} / ${c.max_uses}`;
            const expiryText = c.expiry
                ? formatDate(c.expiry)
                : '<span style="color:var(--text-muted)">—</span>';
            const scopeBadge = c.is_private
                ? `<span class="badge badge-private" title="${escapeHtml(locale.badge_private || 'Private')}"><i class="fas fa-lock"></i> ${escapeHtml(locale.badge_private || 'Private')}</span>`
                : `<span class="badge badge-public" title="${escapeHtml(locale.badge_public || 'Public')}"><i class="fas fa-globe"></i> ${escapeHtml(locale.badge_public || 'Public')}</span>`;

            const creatorName = c.creator_name || c.created_by || '—';
            const creatorSteam = c.creator_steam || '';
            const creatorSteamLabel = creatorSteam ? `
                <div class="steam-hex-container" style="margin-top: 1px;">
                    <i class="fab fa-steam" style="color: var(--text-muted); font-size: 0.75rem;"></i>
                    <span class="steam-hex-text creator-steam-hex" title="${escapeHtml(locale.title_copy_steam || 'Click to copy Steam HEX')}" style="font-size: 0.68rem;">${escapeHtml(creatorSteam)}</span>
                </div>
            ` : '';
            const creatorTd = `
                <td>
                    <div style="display: flex; flex-direction: column; align-items: flex-start; justify-content: center; line-height: 1.2;">
                        <span style="font-weight: 500; font-size: 0.82rem;">${escapeHtml(creatorName)}</span>
                        ${creatorSteamLabel}
                    </div>
                </td>
            `;

            tr.innerHTML = `
                <td>
                    <div class="code-cell">
                        <code class="clickable-code" title="${escapeHtml(locale.title_click_copy || 'Click to copy')}">${escapeHtml(c.code)}</code>
                        <button class="btn-copy-code" title="${escapeHtml(locale.title_copy_code || 'Copy code')}">
                            <i class="fas fa-copy"></i>
                        </button>
                    </div>
                </td>
                <td>${typeBadge}</td>
                <td>${rewardsText}</td>
                <td>${usesText}</td>
                <td>${expiryText}</td>
                <td>${scopeBadge}</td>
                ${creatorTd}
                <td>
                    <button class="edit-code-btn" title="${escapeHtml(locale.admin_edit_btn || 'Edit')}">
                        <i class="fas fa-pen-to-square"></i> ${escapeHtml(locale.admin_edit_btn || 'Edit')}
                    </button>
                    <button class="delete-code-btn" data-code="${escapeHtml(c.code)}" title="${escapeHtml(locale.admin_delete_btn || 'Delete')}">
                        <i class="fas fa-trash-can"></i> ${escapeHtml(locale.admin_delete_btn || 'Delete')}
                    </button>
                </td>
            `;

            tr.querySelector('.btn-copy-code').addEventListener('click', () => {
                copyToClipboard(c.code);
                showToast('success', (locale.toast_code_copied || 'Code copied:') + ' ' + c.code);
            });
            tr.querySelector('.clickable-code').addEventListener('click', () => {
                copyToClipboard(c.code);
                showToast('success', (locale.toast_code_copied || 'Code copied:') + ' ' + c.code);
            });
            if (creatorSteam) {
                const steamEl = tr.querySelector('.creator-steam-hex');
                if (steamEl) {
                    steamEl.addEventListener('click', () => {
                        copyToClipboard(creatorSteam);
                        showToast('success', (locale.toast_creator_steam_copied || 'Creator Steam HEX copied:') + ' ' + creatorSteam);
                    });
                }
            }
            tr.querySelector('.edit-code-btn').addEventListener('click', () => {
                editCode(c);
            });
            const delBtn = tr.querySelector('.delete-code-btn');
            let delTimeout = null;
            delBtn.addEventListener('click', () => {
                if (delBtn.classList.contains('confirm')) {
                    clearTimeout(delTimeout);
                    delTimeout = null;
                    deleteCode(c.code);
                } else {
                    delBtn.classList.add('confirm');
                    delBtn.innerHTML = `<i class="fas fa-trash-can"></i><span>${escapeHtml(locale.admin_confirm_delete || 'Sure?')}</span>`;
                    delTimeout = setTimeout(() => {
                        delBtn.classList.remove('confirm');
                        delBtn.innerHTML = '<i class="fas fa-trash-can"></i>';
                        delTimeout = null;
                    }, 3500);
                }
            });

            dom.activeCodesBody.appendChild(tr);
        });
    }

    function filterActiveCodes() {
        if (!dom.activeCodesSearch) return;
        const query = dom.activeCodesSearch.value.toLowerCase().trim();
        if (!query) {
            renderActiveCodesList(activeCodes);
            return;
        }

        const filtered = activeCodes.filter((c) => {
            const code = (c.code || '').toLowerCase();
            const type = (c.reward_type || '').toLowerCase();
            const rewards = getRewardsText(c).toLowerCase();
            const creatorName = (c.creator_name || c.created_by || '').toLowerCase();
            const creatorSteam = (c.creator_steam || '').toLowerCase();
            const scope = c.is_private ? 'private' : 'public';

            return code.includes(query) ||
                   type.includes(query) ||
                   rewards.includes(query) ||
                   creatorName.includes(query) ||
                   creatorSteam.includes(query) ||
                   scope.includes(query);
        });

        renderActiveCodesList(filtered);
    }

    function getTypeBadge(type) {
        switch (type) {
            case 'money': return '<span class="badge badge-money"><i class="fas fa-dollar-sign"></i> ' + escapeHtml(locale.admin_reward_money || 'Money') + '</span>';
            case 'item':  return '<span class="badge badge-item"><i class="fas fa-box-open"></i> ' + escapeHtml(locale.admin_reward_item || 'Item') + '</span>';
            case 'both':  return '<span class="badge badge-both"><i class="fas fa-layer-group"></i> ' + escapeHtml(locale.admin_reward_both || 'Both') + '</span>';
            default:      return '<span class="badge">' + escapeHtml(type) + '</span>';
        }
    }

    function getRewardsText(code) {
        const parts = [];
        if (code.reward_type === 'money' || code.reward_type === 'both') {
            if (Array.isArray(code.moneys) && code.moneys.length > 0) {
                code.moneys.forEach((m) => {
                    parts.push(moneyLabel(m.type, m.label) + ' $' + formatNumber(m.amount));
                });
            } else if (code.money) {
                parts.push('$' + formatNumber(code.money));
            }
        }
        if ((code.reward_type === 'item' || code.reward_type === 'both') && code.items) {
            const itemsArr = Array.isArray(code.items) ? code.items : Object.values(code.items);
            if (itemsArr.length > 0) {
                itemsArr.forEach((it) => {
                    if (it && typeof it === 'object') {
                        parts.push(`${escapeHtml(it.label || it.name)} x${it.amount || 1}`);
                    }
                });
            }
        }
        return parts.join(', ') || '—';
    }

    function renderHistory() {
        if (dom.historySearch) {
            dom.historySearch.value = '';
        }
        renderHistoryList(historyData);
    }

    function renderHistoryList(data) {
        dom.historyBody.innerHTML = '';

        if (!data || data.length === 0) {
            dom.historyEmpty.classList.remove('hidden');
            return;
        }

        dom.historyEmpty.classList.add('hidden');

        data.forEach((h) => {
            const tr = document.createElement('tr');
            const rewardsText = getHistoryRewardsText(h);
            const playerName = h.redeemed_by_name || h.redeemed_by || '—';
            const citizenIdLabel = h.redeemed_by ? ` <span style="font-family:var(--font-mono); font-size: 0.74rem; color: var(--text-muted); background: var(--well); padding: 1px 4px; border-radius: 4px; border: 1px solid var(--hairline);">(${escapeHtml(h.redeemed_by)})</span>` : '';
            
            const steamHex = h.steam || '';
            const steamHexLabel = steamHex ? `
                <div class="steam-hex-container">
                    <i class="fab fa-steam" style="color: var(--text-muted); font-size: 0.8rem;"></i>
                    <span class="steam-hex-text" title="${escapeHtml(locale.title_copy_steam || 'Click to copy Steam HEX')}">${escapeHtml(steamHex)}</span>
                    <i class="fas fa-copy copy-steam-btn" title="${escapeHtml(locale.title_copy_steam || 'Click to copy Steam HEX')}"></i>
                </div>
            ` : '';

            tr.innerHTML = `
                <td><code>${escapeHtml(h.code)}</code></td>
                <td>
                    <div style="display: flex; flex-direction: column; align-items: flex-start; justify-content: center;">
                        <div style="display: flex; align-items: center; gap: 0.4rem;">
                            <span>${escapeHtml(playerName)}</span>
                            ${citizenIdLabel}
                        </div>
                        ${steamHexLabel}
                    </div>
                </td>
                <td>${h.redeemed_at ? formatDate(h.redeemed_at) : '—'}</td>
                <td>${rewardsText}</td>
            `;

            if (steamHex) {
                const textEl = tr.querySelector('.steam-hex-text');
                const btnEl = tr.querySelector('.copy-steam-btn');
                const copyAction = () => {
                    copyToClipboard(steamHex);
                    showToast('success', (locale.toast_steam_copied || 'Steam HEX copied:') + ' ' + steamHex);
                };
                if (textEl) textEl.addEventListener('click', copyAction);
                if (btnEl) btnEl.addEventListener('click', copyAction);
            }

            dom.historyBody.appendChild(tr);
        });
    }

    function filterHistoryLogs() {
        if (!dom.historySearch) return;
        const query = dom.historySearch.value.toLowerCase().trim();
        if (!query) {
            renderHistoryList(historyData);
            return;
        }

        const filtered = historyData.filter((h) => {
            const code = (h.code || '').toLowerCase();
            const name = (h.redeemed_by_name || '').toLowerCase();
            const citizenid = (h.redeemed_by || '').toLowerCase();
            const steam = (h.steam || '').toLowerCase();
            const rewards = getHistoryRewardsText(h).toLowerCase();

            return code.includes(query) ||
                   name.includes(query) ||
                   citizenid.includes(query) ||
                   steam.includes(query) ||
                   rewards.includes(query);
        });

        renderHistoryList(filtered);
    }

    function getHistoryRewardsText(h) {
        const parts = [];
        if (Array.isArray(h.moneys) && h.moneys.length > 0) {
            h.moneys.forEach((m) => {
                parts.push(moneyLabel(m.type, m.label) + ' $' + formatNumber(m.amount));
            });
        } else if (h.money && h.money > 0) {
            parts.push('$' + formatNumber(h.money));
        }
        if (h.items_text && h.items_text.trim() !== '') {
            parts.push(escapeHtml(h.items_text));
        }
        return parts.join(', ') || '—';
    }

    const TOAST_ICONS = {
        success: 'fa-circle-check',
        error:   'fa-circle-xmark',
        info:    'fa-circle-info',
        warning: 'fa-triangle-exclamation',
    };

    const TOAST_DURATION = 4000;

    function showToast(type, message) {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.style.setProperty('--toast-duration', TOAST_DURATION + 'ms');

        toast.innerHTML = `
            <i class="fas ${TOAST_ICONS[type] || TOAST_ICONS.info} toast-icon"></i>
            <span class="toast-message">${escapeHtml(message)}</span>
            <button class="toast-close"><i class="fas fa-xmark"></i></button>
            <div class="toast-progress"></div>
        `;

        toast.querySelector('.toast-close').addEventListener('click', () => {
            dismissToast(toast);
        });

        dom.toastContainer.appendChild(toast);

        setTimeout(() => {
            dismissToast(toast);
        }, TOAST_DURATION);
    }

    function dismissToast(toast) {
        if (toast.classList.contains('toast-exit')) return;
        toast.classList.add('toast-exit');
        toast.addEventListener('animationend', () => {
            toast.remove();
        });
    }

    dom.redeemCloseBtn.addEventListener('click', closeUI);
    dom.adminCloseBtn.addEventListener('click', closeUI);

    let clearHistoryTimeout = null;
    if (dom.clearHistoryBtn) {
        dom.clearHistoryBtn.addEventListener('click', () => {
            if (dom.clearHistoryBtn.classList.contains('confirm')) {
                dom.clearHistoryBtn.classList.remove('confirm');
                const span = dom.clearHistoryBtn.querySelector('span');
                if (span) span.textContent = locale.admin_btn_clear_history || 'Clear History';
                Dbg.log('UI', 'admin clear history submit');
                postNUI('clearHistory', {});
                if (clearHistoryTimeout) {
                    clearTimeout(clearHistoryTimeout);
                    clearHistoryTimeout = null;
                }
            } else {
                dom.clearHistoryBtn.classList.add('confirm');
                const span = dom.clearHistoryBtn.querySelector('span');
                if (span) span.textContent = locale.admin_confirm_are_you_sure || 'Are you sure?';
                
                clearHistoryTimeout = setTimeout(() => {
                    dom.clearHistoryBtn.classList.remove('confirm');
                    if (span) span.textContent = locale.admin_btn_clear_history || 'Clear History';
                }, 4000);
            }
        });
    }

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (dom.playersModal && !dom.playersModal.classList.contains('hidden')) {
                closePlayersModal();
            } else if (dom.itemsModal && !dom.itemsModal.classList.contains('hidden')) {
                closeItemsModal();
            } else {
                closeUI();
            }
        }
    });

    function postNUI(action, data) {
        const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 's82';
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch((err) => {
            Dbg.err('post ' + action + ' failed: ' + err);
        });
    }

    function copyToClipboard(text) {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        try {
            document.execCommand('copy');
        } catch (err) {
            console.error('Failed to copy: ', err);
        }
        document.body.removeChild(textarea);
    }

    function escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.appendChild(document.createTextNode(str));
        return div.innerHTML;
    }

    function escapeAttr(str) {
        return String(str == null ? '' : str).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function formatNumber(num) {
        return Number(num).toLocaleString(locale.locale_code || 'en-US');
    }

    function formatDate(dateStr) {
        try {
            const d = new Date(dateStr);
            if (isNaN(d.getTime())) return escapeHtml(dateStr);
            return d.toLocaleDateString(locale.locale_code || 'en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
            });
        } catch {
            return escapeHtml(dateStr);
        }
    }

    function shakeInput(el) {
        el.style.animation = 'none';
        void el.offsetHeight;
        el.style.animation = 'shake 0.4s ease-in-out';
        el.addEventListener('animationend', () => {
            el.style.animation = '';
        }, { once: true });
    }

})();