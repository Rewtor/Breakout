-- Ping HTTP simples para a API do Egg Radar.
-- Somente GET /health: sem chaves, arquivos ou dados do jogo.
-- Este endereço é temporário e depende do túnel ativo.
local ping = request or http_request or (http and http.request)

if type(ping) ~= "function" then
    warn("HTTP indisponível")
    return
end

local ok, resposta = pcall(ping, {
    Url = "https://sapphire-baltimore-mozilla-double.trycloudflare.com/health",
    Method = "GET"
})

if ok and type(resposta) == "table" then
    print("HTTP:", resposta.StatusCode or resposta.Status)
    print("Resposta:", resposta.Body)
else
    warn("Falha no ping")
end
