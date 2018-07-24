# CloudFareLogs no Google BigQuery

## Descrição
Este serviço faz a configuração entre o CloudFare e Google BigQuery para salvar os logs. O script main.sh cria uma VM GCC que executa a ferramenta Logshare da Cloudflare em uma programação cron para enviar os Logs para o BigQuery. Os Logs são gravados no GCS e, em seguida, enviados automaticamente para o BigQuery usando o código GCS-To-Big-Query .

## Padrão de Funcionamento
O cron job é executado a cada 1 minuto e puxa os logs de 10 minutos para 11 minutos atrás.
Os campos do endpoint do ELS estão sujeitos a alterações. No momento em que a VM é criada, armazenamos em cache uma versão local dos campos disponíveis. Isso está sujeito a alterações, mas pode ser atualizado manualmente, modificando o arquivo fields.txt.

## Requisitos
   * jq
   * Python 2.7.9
   * curl

---


## Pré-Setup
1. Baixar jq, curl, Python 2.7.9
2. Colocar a pasta jq e curl no C: ou na pasta que você preferir. 
3. Instalar o Python 2.7.9.
4. Instalar o SDK do Google Cloud Plataforme
4. Em Pesquisar, procure e selecione: Sistema (Painel de Controle)
5. Clique no link Configurações avançadas do sistema.
6. Clique em Variáveis de Ambiente. Na seção Variáveis do Sistema, localize a variável de ambiente PATH e selecione-a. Clique em Editar. Se a variável de ambiente PATH não existir, clique em Novo.
7. E crie os seguintes caminhos: 
    * C:\curl
    * C:\Python27
    * C:\Python27\Scripts
    * C:\jq
    * Exemplo C:\Google\CloudSdk
8. Clique em OK. Feche todas as janelas restantes clicando em OK.
9. Abra o CMD e verifique se o Python, jq e curl estão instalados.
#### Para verificar digitar, "python", "curl" e "jq" no CMD
10. Baixar o script 
 * ```git clone https://github.com/cloudflare/GCS-Logshare-Setup-Script.git ```
11. Para Windows, alterar o main.sh na linha 70 e 73 de gsutil para gsutil.cmd

## Setup

1. Selecione ou crie um projeto do Cloud Platform:
    * https://console.cloud.google.com/

2. Ative a API de gerenciamento de serviços para seu projeto:
    * https://console.developers.google.com/apis/api/servicemanagement.googleapis.com/overview
3. Configure e ative seu perfil de faturamento do Google:
    * https://support.google.com/cloud/answer/6293499#enable-billing    
4. Ative as seguintes APIs do Google aqui :
    * Google Cloud Storage
    * Google BigQuery,
    * Cloud Function
5. Crie uma cópia do default.config.json e renomeie para config.json
    * ```mv config.default.json config.json```
6. Modifique o config.json com os detalhes da sua conta do cloudflare
    * Cloudflare_api_key - Chave da API do Cloudflare
    * Cloudflare_api_email - endereço de e-mail da conta de usuário do Cloudflare
    * Zone_name - nome de domínio; exemplo: mydomain.com
    * Gcs_project_id - ID do projeto do Google Cloud
7. Execute o script de orquestração principal:
    * ``` bash main.sh ```
