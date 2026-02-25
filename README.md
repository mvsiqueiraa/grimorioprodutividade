# 🧙‍♂️ Grimório de Estudos

> "Transformando a rotina de estudos e tarefas em uma jornada épica."

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Status](https://img.shields.io/badge/Status-Finalizado-success?style=for-the-badge)

## 📖 Sobre o Projeto

O **Grimório de Estudos** é um aplicativo mobile desenvolvido para auxiliar na organização de tarefas e rotina de estudos, com foco especial em acessibilidade para pessoas com **TDAH**.

Diferente de listas de tarefas comuns ("To-Do Lists") que podem ser desmotivadoras, este projeto utiliza **Gamificação** e uma estética **Medieval/RPG** para tornar o ato de concluir tarefas satisfatório, simulando o preenchimento de um livro de magias ou missões.

O projeto foi essencial para consolidar conhecimentos em persistência de dados local e construção de UI customizada.

---

## 📱 Telas do Aplicativo

<div align="center">
  <img src="screenshots/tela_inicial.jpeg" alt="Tela Inicial do Grimório" width="250"/>
  <img src="screenshots/adicionar_tarefa.jpeg" alt="Adicionando Missão" width="250"/>
  <img src="screenshots/concluido.jpeg" alt="Tarefa Concluída" width="250"/>
</div>

---

## ⚔️ Funcionalidades

- [x] **Gerenciamento de Missões:** Adicionar e remover tarefas diárias.
- [x] **Persistência de Dados:** As tarefas ficam salvas no celular mesmo fechando o app (uso de `shared_preferences`).
- [x] **Interface Temática:** UI Dark Mode com fontes e cores inspiradas em RPGs medievais.
- [x] **Feedback Visual:** Indicadores visuais claros para tarefas pendentes e concluídas.

## 🛠️ Tecnologias Utilizadas

* **Flutter & Dart:** Framework principal.
* **Shared Preferences:** Para armazenamento local de dados.
* **Google Fonts:** Para a tipografia temática (MedievalSharp).
* **VS Code:** Ambiente de desenvolvimento.

## 🚀 Como rodar o projeto

Pré-requisitos: Ter o [Flutter](https://flutter.dev/docs/get-started/install) instalado.

```bash
# Clone este repositório
$ git clone [https://github.com/SEU_USUARIO/grimorio_estudos.git](https://github.com/SEU_USUARIO/grimorio_estudos.git)

# Entre na pasta
$ cd grimorio_estudos

# Instale as dependências
$ flutter pub get

# Execute o app
$ flutter run
