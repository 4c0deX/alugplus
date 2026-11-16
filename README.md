<div align="center">

<img src="icons/alugplus-icon.png" alt="AlugPlus+ Logo" width="96" height="96" />

# AlugPlus+ • Web Deploy (`gh-pages`)

**Build de produção Flutter Web publicada no GitHub Pages — Edição Purple.**

[![Acessar Site](https://img.shields.io/badge/GitHub_Pages-Acessar_AlugPlus+-7C3AED?style=for-the-badge&logo=githubpages&logoColor=white)](https://4c0dex.github.io/alugplus/)
[![Branch gh-pages](https://img.shields.io/badge/Branch-gh--pages-5B21B6?style=for-the-badge&logo=git&logoColor=white)](#)
[![Flutter Web](https://img.shields.io/badge/Flutter_Web-CanvasKit-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![SQLite WASM](https://img.shields.io/badge/SQLite_Web-WASM_Offline-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org)

[Abrir Aplicação](https://4c0dex.github.io/alugplus/) •
[Sobre esta Branch](#-sobre-esta-branch) •
[Estrutura do Deploy](#-estrutura-do-deploy) •
[Como Atualizar](#-como-atualizar-o-deploy)

</div>

---

## 🌐 Sobre esta Branch

Esta branch (`gh-pages`) contém **apenas os arquivos estáticos compilados** (`build/web`) para publicação direta no **GitHub Pages** em:

> 🔗 **https://4c0dex.github.io/alugplus/**

O código-fonte Dart/Flutter do projeto fica nas branches de desenvolvimento (`Purple` / `main`).

### Destaques desta publicação Web

| Recurso | Detalhe Técnico |
| :--- | :--- |
| **🧭 Roteamento em Subcaminho** | Configurado com `<base href="/alugplus/">` em `index.html` para funcionamento correto no GitHub Pages. |
| **🎨 Renderização CanvasKit Local** | Motor gráfico carregado diretamente de `canvaskit/` via `flutter_bootstrap.js`, sem depender de CDN externo. |
| **🗄️ Banco Local no Navegador** | Persistência offline-first utilizando `sqlite3.wasm` + Web Worker (`sqflite_sw.js`). |
| **🚫 Jekyll Desativado** | Inclui `.nojekyll` na raiz para que todos os assets e scripts estáticos sejam servidos sem filtros. |
| **📱 Suporte a PWA** | Configurado com `manifest.json` e ícones responsivos em `icons/` para instalação no celular ou desktop. |

---

## 📦 Estrutura do Deploy

```text
.
├── .nojekyll                # Desativa o processamento Jekyll do GitHub Pages
├── index.html               # Entrada da aplicação (<base href="/alugplus/">)
├── flutter_bootstrap.js     # Loader do Flutter Web (CanvasKit local)
├── main.dart.js             # Aplicação AlugPlus+ compilada
├── sqflite_sw.js            # Shared/Web Worker do SQLite
├── sqlite3.wasm             # Binário WebAssembly do SQLite
├── manifest.json            # Manifesto PWA (#5B21B6)
├── canvaskit/               # Engine gráfica CanvasKit local
├── assets/                  # Fontes e recursos da aplicação
└── icons/                   # Ícones do aplicativo e PWA
```

---

## 🚀 Como Atualizar o Deploy

Sempre que gerar uma nova compilação web a partir da branch de código-fonte:

```bash
# 1. Gerar o build com o base-href do repositório
flutter build web --base-href /alugplus/

# 2. Garantir o arquivo .nojekyll na pasta build/web
touch build/web/.nojekyll

# 3. Commitar e enviar a pasta build/web para a branch gh-pages
git -C build/web add -A
git -C build/web commit -m "Deploy Flutter Web"
git -C build/web push origin gh-pages
```

> **Dica:** após o push, aguarde ~1 minuto para o GitHub Pages concluir a publicação e use `Ctrl + Shift + R` (ou aba anônima) caso o navegador mantenha cache do Service Worker anterior.
