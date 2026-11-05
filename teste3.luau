            counts.claimed = counts.claimed + 1
        elseif not collectionDestination(model, rec) then
            counts.noModel = counts.noModel + 1
            pendingData = true
        elseif not data or not data.Ready then
            counts.pending = counts.pending + 1
            pendingData = true
        else
            if not bestRate or data.R > bestRate
                or (data.R == bestRate and uid < bestUid) then
                bestUid, bestModel, bestRecord, bestRate = uid, model, rec, data.R
            end
        end
    end
    if bestUid and not (pendingData and now - collector.startedAt < 12) then
        collector.pending = false
        collector.attempted[bestUid] = true
        collectorBusy = true
        task.spawn(runCollection, bestUid, bestModel, bestRecord)
    else
        -- Falta de dados nao consome o lote. Nova verificacao no proximo scan.
        collectionMessage(string.format(
            "Aguardando: %d ovos | sem posicao: %d | renda pendente: %d\nColetados: %d | tentados: %d",
            counts.total, counts.noModel, counts.pending, counts.claimed, counts.tried))
    end
end

local lastScanWarning = 0

local function scan()
    loadModules()

    local models, records, all = collectSources()
    local total, targets, best, errors = 0, 0, 0, 0
    local now = os.clock()

    for uid in pairs(all) do
        total = total + 1

        local ok, data = pcall(
            updateEgg, uid, models[uid], records[uid] or emptyRecord, now
        )

        if ok and data then
            best = math.max(best, data.R)

            if isTarget(data) then
                targets = targets + 1
                notifyEgg(uid)
            end
        else
            errors = errors + 1
            -- Não deixa valor antigo continuar sendo alvo após erro.
            if cached[uid] then
                cached[uid] = nil
                cacheState[uid] = nil
                dataVersion = dataVersion + 1
            end
        end
    end

    for uid in pairs(cached) do
        if not all[uid] then
            cached[uid] = nil
            cacheState[uid] = nil
            knownSources[uid] = nil
            notified[uid] = nil
            dataVersion = dataVersion + 1

            -- Libera objetos de ovos removidos mesmo com painel escondido.
            local row = rows[uid]
            if row then
                row.frame:Destroy()
                rows[uid] = nil
            end
        end
    end

    for uid in pairs(cacheState) do
        if not all[uid] then
            cacheState[uid] = nil
            knownSources[uid] = nil
        end
    end

    updateCollection(models, records, all, now)

    if targets > 0 or collectorBusy then
        lastValidEggTime = now
    elseif errors == 0 and cfg.AH and not isHopping
        and now - lastValidEggTime >= cfg.AHT then
        task.spawn(doServerHop)
    end

    if not minimized and not mobile then
        local stateText = "Monitorando o mapa"

        if cfg.AH and targets == 0 then
            local remaining = math.max(
                0, math.ceil(cfg.AHT - (now - lastValidEggTime))
            )
            stateText = "Sem alvos • hop em " .. remaining .. "s"
        end

        setText(stat, string.format(
            "%s\nOvos: %d • Alvos: %d\nMelhor: $%s/s",
            stateText, total, targets, short(best)
        ))
    end

    if errors > 0 and now - lastScanWarning >= 10 then
        lastScanWarning = now
        warn("[Dice Radar] Falha de leitura em " .. errors .. " ovo(s); nova tentativa no próximo ciclo.")
    end

    render()
end

body.Visible = false
minimizeButton.Text = "+"

layout()

task.spawn(function()
    while alive do
        if not paused then
            local ok, err = pcall(scan)

            if not ok and alive then
                setText(stat, "Falha ao atualizar. Tentando novamente...")
                local now = os.clock()

                if now - lastScanWarning >= 10 then
                    lastScanWarning = now
                    warn("[Dice Radar] " .. tostring(err))
                end
            end
        end

        task.wait(SCAN_INTERVAL)
    end
end)
