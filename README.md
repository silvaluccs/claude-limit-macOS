# Claude Touch Bar

Coloca o **Clawd**, o mascote do Claude Code, digitando num notebook na **Touch Bar**
do MacBook Pro. Toque nele para abrir o
painel com o **uso da sessão (5h)** e o **uso semanal** do seu plano, com o
horário de reset de cada um.

- O Clawd digita devagar quando está ocioso. Quando o uso da sessão sobe, ele digita rápido e balança.
- No painel, um toque ou deslize na barra troca entre **Sessão** e **Semana**, com uma animação de subida.
  A Touch Bar só detecta movimento horizontal, então não há gesto vertical.
- O logo da tampa do notebook e o percentual mudam de cor a partir de 70% (amarelo) e de 90% (vermelho).
- Para fechar o painel, toque no Clawd de novo.
- Também mostra `sessão% · semana%` na barra de menus, com o menu para atualizar ou sair.

## Como funciona

- **Dados:** lê o token OAuth que o Claude Code guarda no Keychain
  (`Claude Code-credentials`) e consulta `https://api.anthropic.com/api/oauth/usage`,
  o mesmo endpoint por trás do `/usage`. Esse endpoint **não é documentado** e
  pode mudar. O app nunca renova o token; se ele expirar, basta abrir o Claude Code.
- **Touch Bar:** usa APIs privadas do `DFRFoundation` (as mesmas do Pock e do MTMR)
  para fixar o item na Control Strip e abrir um painel que funciona em qualquer app.

## Requisitos

- MacBook Pro com Touch Bar
- Claude Code logado com uma conta Pro/Max
- Swift 5.9+ (as Command Line Tools bastam, não precisa do Xcode)

## Build

```bash
scripts/build-app.sh            # gera build/ClaudeTouchBar.app
scripts/build-app.sh --install  # e copia para ~/Applications
open ~/Applications/ClaudeTouchBar.app
```

Se o ícone não aparecer, verifique em *Ajustes do Sistema → Teclado → Configurações
da Touch Bar* se a opção “Mostrar Control Strip” está ligada.
