> [!CAUTION]
> Desde 7 de abril de 2026 o Discord passou a punir quem completa missões automaticamente.
>
> Alguns usuários receberam este aviso:
>
> <img width="836" height="272" alt="aviso do Discord sobre automação de missões" src="https://github.com/user-attachments/assets/db4c7641-dd57-412e-a625-f39a363f2138" />
>
> Não tem como deixar o plugin indetectável. Use por sua conta e risco. Sua conta provavelmente vai ser marcada.

# CompleteDiscordQuest para Vencord

Plugin do Vencord que completa várias missões do Discord ao mesmo tempo, em segundo plano.

Port do plugin de BetterDiscord [CompleteDiscordQuest](https://github.com/nicola02nb/BetterDiscord-Stuff/tree/main/Plugins/CompleteDiscordQuest).

## Instalação

1. Instale o [Vencord](https://vencord.dev/) a partir do código fonte.
2. Clone este repositório em `Vencord/src/userplugins`:

```bash
cd Vencord/src/userplugins
git clone https://github.com/luanwolf/completeDiscordQuest.git
```

3. Reinjete o Vencord (`pnpm inject` na pasta do Vencord) e reinicie o Discord.
4. Ative o plugin em Configurações do Vencord > Plugins.

Na primeira reinicialização depois de ativar, aparece um aviso de risco. OK liga a automação. Cancelar deixa desligada (você pode ligar depois nas opções do plugin).

## O que faz

- Aceita missões sozinho (opcional)
- Completa vídeo, jogar no app, transmitir e atividade
- Filtra por tipo de missão e de recompensa
- Botão de missões na barra de cima e no card do usuário (mudo, fone, configurações)

## Créditos

- Trecho original: [aamiaa](https://github.com/aamiaa)
- Port Vencord: [nicola02nb](https://github.com/nicola02nb/completeDiscordQuest)
- Esta versão: **heyash**
