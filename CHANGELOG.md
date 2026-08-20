## 2.0.0

* **Quebra de compatibilidade** `VitMultiPaneView.dividerBuilder` agora recebe
  um terceiro parâmetro, `isMouseOver`. Ele reflete o hover da área de pega
  inteira (`dividerHitWidth`), não só da linha visual fina — assim divisórias
  customizadas já mudam de aparência quando o cursor muda, sem esperar o
  mouse chegar bem no centro.

## 1.1.0

* **Adicionado** `VitMultiPaneController.setProportions`: redistribua o
  espaço entre os painéis por código a qualquer momento — ex.: dar mais
  espaço a um painel ou igualar todos. Os tamanhos mínimo e máximo de cada
  painel seguem valendo.
* **Adicionado** `VitMultiPaneView.initialProportions`: defina o tamanho
  relativo de cada painel na primeira exibição (ex.: abrir com o painel da
  esquerda menor); depois disso, o ajuste é do usuário.

## 1.0.0

* **Adicionado** arraste de divisórias suave, que acompanha o ponteiro.
  Cada divisória redimensiona apenas os dois painéis vizinhos; os demais só
  entram no movimento quando um vizinho atinge seu tamanho mínimo ou máximo.
* **Adicionado** `VitMultiPaneView.dividerHitWidth`: divisórias finas
  continuam fáceis de arrastar — a área de clique é maior que a linha
  visível. No desktop, o cursor muda ao passar sobre a divisória.
