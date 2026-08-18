# vit_multi_pane

Layout de múltiplos painéis para Flutter: as páginas ficam lado a lado, com
uma divisória arrastável entre elas. Todas as páginas do controller estão
sempre visíveis — nada de abas ou navegação escondendo conteúdo.

## Uso

```dart
final controller = VitMultiPaneController()
  ..add(VitMultiPanePage(minWidth: 240, child: HomePage()))
  ..add(VitMultiPanePage(minWidth: 320, maxWidth: 720, child: ReportsPage()));

VitMultiPaneView(controller: controller);
```

Uma página é um `Widget` qualquer. Envolver em `VitMultiPanePage` é opcional e
serve só para declarar `minWidth` / `maxWidth`, que limitam até onde a
divisória pode ser arrastada.

## Controller

O controller é obrigatório: quem manda na lista de páginas é o app, não o
widget. Ele é um `ChangeNotifier`, então dá para reagir a mudanças com
`ListenableBuilder`.

```dart
controller.add(NewPage());              // acrescenta ao final
controller.replaceAt(1, OtherPage());   // troca a página no índice 1
controller.removeAt(0);                 // remove
controller.setCurrentIndex(2);          // marca a página ativa
```

`currentIndex` é apenas estado — a view não muda de aparência por causa dele.
Use quando o seu app precisa saber em qual painel o usuário está atuando (uma
barra de status, um atalho de teclado, etc.).

Como o índice de uma página muda quando outras são removidas, resolva a
posição na hora da ação em vez de capturar o índice na construção:

```dart
onClose: () {
  final index = controller.pages.indexOf(page);
  if (index != -1) controller.removeAt(index);
}
```

## Divisória

O arraste é do pacote; a aparência é sua. `dividerBuilder` recebe uma caixa de
`dividerWidth` × altura total e pinta o que você quiser dentro:

```dart
VitMultiPaneView(
  controller: controller,
  dividerWidth: 6,
  dividerHitWidth: 16,
  dividerBuilder: (context, dividerIndex) => ColoredBox(
    color: Colors.grey.shade200,
    child: Center(
      child: Container(width: 2, height: 40, color: Colors.grey),
    ),
  ),
);
```

`dividerHitWidth` (12px por padrão) é a largura da área de pega, independente
da espessura visual: uma divisória de 1px continua fácil de agarrar. Essa área
é sobreposta e translúcida ao hit-test — ela não ocupa espaço no layout nem
engole os toques e hovers do conteúdo das páginas embaixo dela.

## Comportamento do arraste

- A divisória fica exatamente sob o ponteiro, um pixel de tela por pixel de
  movimento — arrastar de volta ao ponto de origem restaura as larguras
  originais.
- Um arraste move só os dois painéis que a divisória separa. Os painéis além
  deles só começam a mexer quando o vizinho encosta no próprio `minWidth` /
  `maxWidth`.
- As larguras são guardadas como frações, então redimensionar a janela
  reescala o layout em vez de esticar um painel só.
- Funciona sob `Directionality.rtl`: a direção do arraste e as áreas de pega
  acompanham o sentido do texto.

Rode `example/` para um demo interativo (adicionar e remover painéis, editar
`minWidth` / `maxWidth` em tempo real).
