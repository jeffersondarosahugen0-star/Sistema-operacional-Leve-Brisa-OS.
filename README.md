# Brisa OS

Sistema Linux (Debian 12 + XFCE) leve, em português, com visual inspirado no Windows 11, para PCs antigos (x86_64, BIOS Legacy/MBR).

## Estado
- Código-fonte, scripts, instalador (Calamares), fluxo de compilação na nuvem e site: prontos.
- **ISO real compilada e testada: ainda não.** Depende de rodar o GitHub Actions (abaixo). O site só habilita o download depois disso.

## Compilar na nuvem (o que depende de você)
1. Crie um repositório **público** no GitHub e envie o conteúdo desta pasta (incluindo a pasta oculta `.github`).
2. Em **Settings → Pages → Source**, escolha **GitHub Actions** (uma vez).
3. Em **Actions → Compilar ISO e publicar site → Run workflow**.
4. Ao terminar (30 a 90 min): a ISO aparece em **Releases**, o site é publicado em Pages com o link real. Se falhar, me envie o log.

O workflow: compila num container Debian 12, tenta caber em 1,2 GB (remove jogos/apps extras sozinho e recompila), confere MBR/Syslinux/squashfs, boota no QEMU em BIOS legado, captura a tela e publica tudo.

## Compilar localmente
Debian 12, root, internet: `./build.sh` (depois `scripts/boot-test.sh brisa-os-0.1-amd64.iso`).

## Pontos fracos conhecidos
- Nenhuma compilação foi executada ainda; falhas de pacote/opção do live-build são esperadas na primeira rodada.
- Steam não vem na ISO (tamanho): há o atalho "Instalar Steam", que baixa pela internet. Proton exige GPU com Vulkan.
- O menu do Syslinux pode esperar uma tecla; o teste automático envia Enter.
- Em computadores UEFI puros o instalador usa GPT; o alvo é BIOS/MBR.
- Sem hardware real testado.
