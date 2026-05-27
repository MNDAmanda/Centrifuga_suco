## Documentação do Projeto - Sistema de Deslodamento (Desludging)

**Projeto:** Centrífuga de Suco - Ciclo de Deslodamento  
**Plataforma:** CODESYS  
**Linguagem:** Structured Text (ST) com equivalência Ladder  
**Data:** 2026-05-27

---

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Requisitos Funcionais](#requisitos-funcionais)
3. [Arquitetura do Sistema](#arquitetura-do-sistema)
4. [Máquina de Estados](#máquina-de-estados)
5. [Presets e Configurações](#presets-e-configurações)
6. [Interface WebVisu](#interface-webvisu)
7. [Como Usar](#como-usar)
8. [Troubleshooting](#troubleshooting)

---

## Visão Geral

Este projeto implementa um **sistema automático de deslodamento** para uma centrífuga de suco. O sistema executa uma sequência controlada de pulsos de diferentes durações para limpeza e desobstrução de tubulações/válvulas.

### Sequência de Ciclo Completo:
- **3 Pulsos Parciais** (1 segundo cada) com **5 segundos de intervalo**
- **1 Pulso Parcial Longo** (6 segundos)
- **1 Pulso Total** (30 segundos)
- **Repetição** conforme necessário

---

## Requisitos Funcionais

| # | Requisito | Status |
|---|-----------|--------|
| 1 | Duas versões: Ladder e ST | ✅ Implementado |
| 2 | Inicialização por DI1 (> 2s) | ✅ Implementado |
| 3 | Parada por DI2 | ✅ Implementado |
| 4 | Controle de DO1 (válvula) | ✅ Implementado |
| 5 | WebVisu com botão parada | ✅ Implementado |
| 6 | Gráfico trace DO1 | ✅ Implementado |
| 7 | Presets configuráveis | ✅ Implementado |
| 8 | Contador de ciclos | ✅ Implementado |
| 9 | Mensagem de tipo deslodamento | ✅ Implementado |

---

## Arquitetura do Sistema

### Variáveis de Entrada
```
DI1_Start : BOOL        → Botão iniciar (hold > 2 segundos)
DI2_Stop : BOOL         → Botão parar ciclo
```

### Variáveis de Saída
```
DO1_Valve : BOOL        → Válvula de deslodamento (0=fechada, 1=aberta)
DO1_Trace : REAL        → Valor analógico para gráfico (0.0 - 1.0)
```

### Variáveis de Controle
```
Is_Running : BOOL       → Flag de sistema ativo
State : INT             → Estado atual da máquina (0-4)
Cycle_Count : DINT      → Contador de ciclos completos
Pulse_Count : INT       → Contador de pulsos no ciclo atual
```

### Variáveis de Status/Display
```
System_Status : STRING          → Status geral ("PARADO", "INICIADO", etc)
Current_Desludge_Type : STRING  → Tipo de deslodamento atual
```

### Presets (Tempo em Milissegundos)
```
Time_Between_Pulses : DINT      = 5000   (5 seg)
Time_Partial_Desludge : DINT    = 1000   (1 seg)
Time_Long_Partial : DINT        = 6000   (6 seg)
Time_Total_Desludge : DINT      = 30000  (30 seg)
```

---

## Máquina de Estados

### Estados Implementados

```
┌─────────────────────────────────┐
│       Estado 0: IDLE            │
│  (Aguardando início do ciclo)   │
└─────────────┬───────────────────┘
              │
              │ DI1 > 2s
              ↓
┌─────────────────────────────────────────┐
│  Estado 1: PULSO PARCIAL (1 segundo)    │
│  DO1 = ON durante 1s, depois OFF        │
│  Pulse_Count++                          │
└──────┬────────────────────────┬─────────┘
       │ Timer finalizado       │
       │                        │ DI2 (parada)
       ↓                        ↓
┌─────────────────────────────────────────┐
│  Estado 4: AGUARDO (5 segundos)         │
│  DO1 = OFF                              │
│  Verifica contador de pulsos            │
└──────┬────────────────────────┬─────────┘
       │ Timer finalizado       │
       │ (Verificar Pulse_Count)│
       │                        │
       ├─ Se Pulse_Count < 3   │
       │  → Estado 1 (Parcial) │
       │                        │
       ├─ Se Pulse_Count = 3   │
       │  → Estado 2 (Long)    │
       │                        │
       └─ Se Pulse_Count = 4   │
          → Estado 3 (Total)   │
              
┌──────────────────────────────────────────────┐
│ Estado 2: PULSO PARCIAL LONGO (6 segundos)   │
│ DO1 = ON durante 6s, depois OFF              │
│ Pulse_Count++                                │
└──────┬──────────────────────────┬────────────┘
       │ Timer finalizado         │
       │                          │ DI2
       ↓                          ↓
  Estado 4 (Aguardo)            Estado 0

┌──────────────────────────────────────────────┐
│ Estado 3: PULSO TOTAL (30 segundos)          │
│ DO1 = ON durante 30s, depois OFF             │
│ Cycle_Count++                                │
└──────┬──────────────────────────┬────────────┘
       │ Timer finalizado         │
       │ Sistema para             │ DI2
       ↓                          ↓
  Estado 0 (IDLE)               Estado 0
  Ciclo Completo!
```

### Tabela de Transições

| Estado Atual | Condição | Próximo Estado | Ação |
|---|---|---|---|
| 0 (IDLE) | DI1 > 2s | 1 (Parcial) | Is_Running = TRUE |
| 1 (Parcial) | Timer finalizado | 4 (Aguardo) | Pulse_Count++, DO1=OFF |
| 2 (Long) | Timer finalizado | 4 (Aguardo) | Pulse_Count++, DO1=OFF |
| 3 (Total) | Timer finalizado | 0 (IDLE) | Cycle_Count++, Is_Running=FALSE |
| 4 (Aguardo) | Timer finalizado, Count<3 | 1 (Parcial) | - |
| 4 (Aguardo) | Timer finalizado, Count=3 | 2 (Long) | - |
| 4 (Aguardo) | Timer finalizado, Count=4 | 3 (Total) | - |
| Qualquer | DI2 pressionado | 0 (IDLE) | Is_Running=FALSE, DO1=OFF |

---

## Presets e Configurações

### Valores Padrão

| Parâmetro | Valor | Descrição |
|---|---|---|
| Time_Between_Pulses | 5000 ms (5s) | Intervalo entre pulsos consecutivos |
| Time_Partial_Desludge | 1000 ms (1s) | Duração do deslodamento parcial |
| Time_Long_Partial | 6000 ms (6s) | Duração do deslodamento parcial longo |
| Time_Total_Desludge | 30000 ms (30s) | Duração do deslodamento total |

### Como Alterar Presets

**Opção 1: Via WebVisu**
1. Acesse a tela da interface WebVisu
2. Localize a seção "CONFIGURAÇÃO DE PRESETS"
3. Insira os novos valores em **segundos** (a conversão para ms é automática)
4. Clique em "RESETAR PADRÕES" para voltar aos originais

**Opção 2: Via CODESYS (durante programação)**
```
Time_Between_Pulses := 6000;      (* 6 segundos *)
Time_Partial_Desludge := 1500;    (* 1.5 segundos *)
Time_Long_Partial := 8000;        (* 8 segundos *)
Time_Total_Desludge := 45000;     (* 45 segundos *)
```

---

## Interface WebVisu

### Componentes Principais

#### 1. **Seção de Controles**
- **Botão PARAR CICLO**: Interrompe o ciclo imediatamente
- **Indicador Visual**: LED verde quando sistema está ativo
- **Status em Tempo Real**: Exibe o estado atual do sistema

#### 2. **Gráfico de Trace**
- **Eixo Y**: Estado do DO1 (0 a 1)
- **Eixo X**: Tempo (segundos)
- **Duas Traçados**:
  - Vermelho: Estado digital (0 ou 1)
  - Azul: Valor analógico suavizado (para melhor visualização)
- **Atualização**: Em tempo real, cada scan do programa

#### 3. **Contador de Ciclos**
- **Ciclos Completos**: Incrementa a cada ciclo total finalizado
- **Pulsos Atuais**: Mostra em qual etapa está (0-4)

#### 4. **Mensagem de Tipo Deslodamento**
Exibe dinamicamente uma das mensagens:
- "Ciclo de deslodamento parcial"
- "Ciclo de deslodamento parcial longo"
- "Ciclo de deslodamento total"
- "Aguardando próximo pulso"
- "Ciclo completo finalizado"

#### 5. **Configuração de Presets**
- Campos editáveis para cada tempo
- Valores exibidos em **segundos**
- Botão para resetar aos padrões
- Valores padrão mostrados para referência

---

## Como Usar

### Passo 1: Inicializar o Sistema
1. Acesse a interface WebVisu no navegador
2. Pressione e mantenha pressionado o **botão DI1 por 2+ segundos**
3. O sistema iniciará automaticamente
4. Você verá o indicador visual ficando verde

### Passo 2: Monitorar o Ciclo
1. Observe o **gráfico de trace** atualizando em tempo real
2. Acompanhe a **mensagem de tipo deslodamento** mudando
3. Veja o contador de **pulsos atuais** incrementando
4. Quando atingir 5 pulsos (3 parciais + 1 longo + 1 total), o ciclo finaliza

### Passo 3: Ajustar Presets (Opcional)
1. Localize a seção "CONFIGURAÇÃO DE PRESETS"
2. Altere os valores conforme necessário
3. Os novos valores serão aplicados no próximo ciclo
4. Clique "RESETAR PADRÕES" para voltar aos originais

### Passo 4: Parar o Ciclo
1. Clique no botão **"PARAR CICLO"** a qualquer momento
2. A válvula DO1 será desativada imediatamente
3. O sistema retorna ao estado IDLE

---

## Troubleshooting

### Problema: O sistema não inicia ao pressionar DI1

**Possíveis Causas:**
- Tempo de pressionamento insuficiente (< 2 segundos)
- DI1 não conectado corretamente
- Botão não configurado na interface

**Solução:**
1. Mantenha o botão pressionado por **exatamente 2+ segundos**
2. Verifique as conexões físicas de DI1
3. Confirme que `DI1_Start` está mapeado corretamente no I/O

---

### Problema: DO1 não ativa/desativa

**Possíveis Causas:**
- Válvula fisicamente travada
- Conexão elétrica defeituosa
- DO1 não mapeado corretamente

**Solução:**
1. Teste a válvula manualmente
2. Verifique alimentação e cabos
3. Confirme mapeamento em I/O Settings

---

### Problema: Gráfico não atualiza

**Possíveis Causas:**
- Conexão WebVisu perdida
- Taxa de atualização muito baixa
- JavaScript desabilitado no navegador

**Solução:**
1. Atualize a página do navegador (F5)
2. Aumente a frequência de atualização em WebVisu Settings
3. Verifique se JavaScript está habilitado

---

### Problema: Presets não mudam

**Possíveis Causas:**
- Valores ainda em milissegundos (não convertidos)
- Cache do navegador
- Ciclo ativo (presets só aplicam no próximo ciclo)

**Solução:**
1. Lembre-se: insira valores em **segundos** (não ms)
2. Limpe cache: Ctrl+Shift+Del
3. Espere o ciclo atual finalizar antes de alterar

---

### Problema: Contador de ciclos não incrementa

**Possíveis Causas:**
- Ciclo não chegando até o estado 3 (Total)
- Sistema parado antes de finalizar

**Solução:**
1. Deixe o ciclo completo sem interrupções
2. Verifique se o estado 3 está sendo atingido via mensagem de status
3. Aumente o tempo de deslodamento total se necessário

---

## Arquivos do Projeto

```
Centrifuga_suco/
├── Deslodamento_Principal.st      ← Código principal em ST
├── Deslodamento_Ladder.txt        ← Diagrama Ladder em texto
├── WebVisu_Configuration.xml      ← Configuração da interface
└── README.md                      ← Esta documentação
```

---

## Versão e Histórico

**v1.0** - 2026-05-27
- ✅ Implementação inicial do sistema
- ✅ Máquina de estados funcional
- ✅ WebVisu com todos os requisitos
- ✅ Documentação completa

---

## Suporte

Para dúvidas ou problemas:
1. Consulte a seção [Troubleshooting](#troubleshooting)
2. Verifique os logs do CODESYS
3. Valide as conexões de hardware
4. Consulte o manual do CODESYS para referência

---

**Desenvolvido para:** MNDAmanda  
**Projeto:** Centrífuga de Suco  
**Tecnologia:** CODESYS 3.5+
