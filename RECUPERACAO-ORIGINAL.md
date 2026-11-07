# Recuperação do original, separada da réplica

Objetivo: recuperar os corpos originais dos callbacks e suas dependências, sem tratá-los como equivalentes a uma reimplementação. O texto fonte anterior à ofuscação, incluindo nomes apagados e comentários, pode não ser recuperável. Desvirtualizar o código e demonstrar equivalência de comportamento é um objetivo distinto de reproduzir esse texto literalmente.

## Base preservada

- StealAnEggg.lua: SHA-256 `41b5de74cc0fc687a884829357f2a7caf68d5b3519c9f30e1276e2698fdcd9ae`.
- Runtime extraído: SHA-256 `49b91a4f0471a76f4c65c9b046a0211b16eee9178bb93136138714ec5c8b3228`.
- Payload extraído: SHA-256 `59c5d12e384404b84c7980f0d21e184b1c5bc920ae87617a30526ee91c4b8876`.

As verificações desta etapa confirmaram esses três hashes. A cópia com a primeira camada removida está em ../entrega/StealAnEgg.layer1.luau e preserva a VM interna. Ela não é uma versão totalmente desofuscada.

## Limite da análise local

Os relatórios anteriores registram a interpretação da VM parada antes da entrada da aplicação. Uma execução antiga de quatro bilhões de instruções também não chegou aos callbacks. Isso não é recuperação dos corpos originais.

Foi criada uma experiência adicional com todas as funções internas preservadas textualmente e interceptação externa somente dos limites de UI/aplicação. Ela construiu a entrada raiz, mas não chegou ao limite de captura da aplicação no tempo observado e foi interrompida. Isso é um bloqueio na reprodução do runtime local; a causa exata ainda não foi comprovada. O caminho novo também corrigiu uma diferença de chamada: com vZ original, XZ já devolve a entrada ligada e não deve receber novamente os argumentos de ligação da VM.

## Captura experimental no ambiente original

Chilli.capture-original.luau é um COLETOR, não a recuperação concluída. Usa os bytes preservados e conserva os corpos das fábricas originais. Acrescenta observadores aos construtores, preservando suas aridades; devolve os binders originais sem envolver seus corpos em callbacks substitutos. As rotinas nativas 0, 50 e 95 são interceptadas para coletar os dados antes de iniciar a aplicação de gameplay.

O inventário possui 14 fábricas numéricas, incluindo 11 e 92, ambas com 19 parâmetros. A captura deve observar também as fábricas nativas, não somente o interpretador 92. A numeração dessas fábricas não equivale à numeração dos dez callbacks da aplicação.

O coletor grava Chilli_OriginalCapture.json e relata quantos dos dez callbacks foram associados a construtores reais. Referências ao runtime, aos ambientes globais e a objetos externos são omitidas do grafo. A saída tem limites de objetos e bytes. Nenhum dos substitutos da réplica é importado.

Uma primeira captura enviada pelo usuário alcançou a aplicação e associou os dez callbacks originais. Entretanto, as especificações de captura eram carregadas sob demanda e ficaram ausentes da serialização. A revisão atual resolve explicitamente essas dez tabelas no ambiente original antes de gravá-las, validando seu formato numérico em triplas. Essa correção passou por teste sintético com metatable lazy, conferência dos bytes originais e compilação; ainda requer uma nova execução no jogo. A recuperação e a equivalência dos callbacks continuam pendentes.

## Ferramentas

A segunda captura (`dc69e8e492bef18b9de7373f91781d002a05164f4a7648681b0651320f35e912`) trouxe as dez especificações, conferidas contra os pontos de ligação nativos: 145 dependências no total, 30 no callback 7. A leitura offline das constantes da camada interna ainda falha em comparações com valores já capturados. A revisão atual resolve também as quatro tabelas de constantes de cada callback usando seus metatables originais, antes da serialização. Essa mudança passou em teste sintético com constantes lazy e na compilação; sua execução no jogo ainda está pendente. Não representa recuperação concluída nem teleporte validado.

- Gerar e conferir bytes/sintaxe: `node recovered/optimization/build-original-capture.cjs`.
- Importar dados sem executar Lua: `node recovered/optimization/import-original-capture.cjs <arquivo.json>`.
- original-factory-catalog.json: localização, aridade e hash de cada fábrica original.
- capture-build.json: verificações e limitações do coletor.
- pristine-manifest.json e pristine-run.json: primeira experiência local, sem captura concluída.

Nenhuma nova implementação de teleporte foi aplicada ao teste5 nesta etapa. Nenhum callback protegido é declarado como recuperado só por ter um substituto ou um ponto de ligação preenchido.
