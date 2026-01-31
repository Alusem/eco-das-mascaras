# Visão Geral do Projeto: O Eco das Máscaras

## Contexto
- **Evento:** Game Jam de 48 horas.
- **Tema:** Investigação em um Baile de Máscaras.
- **Objetivo:** Criar um protótipo funcional, polido e com um loop de gameplay completo (Início, Meio e Fim).

## Tecnologias
- **Engine:** Godot 4.x (GDScript).
- **IA de Apoio:** Cursor (utilizando prompts contextuais).
- **Estilo Visual:** 2D Top-down (Sprites simples, foco em cores de máscaras).
- **Arquitetura:** Baseada em estados (State Pattern) e Data-Driven (usando Resources ou JSON para as pistas).

## Restrições da Jam
1. **Escopo Curto:** Apenas um cenário (Salão de Festas).
2. **Assets Limitados:** Foco em mecânica e narrativa lógica.
3. **Mecânica Única:** Dedução por contradição após troca de máscaras (Blackout Event).

## Stack Técnica no Godot
- `CharacterBody2D` para o Player.
- `Area2D` para interações com NPCs.
- `CanvasLayer` para o Caderno de Evidências e Diálogos.
- `Resource` para definir os NPCs e seus estados (Pre-Blackout e Post-Blackout).