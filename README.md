# Drupal イメージ

## ビルド

1. composer ビルド

    > 環境準備

    ```bash
    sudo add-apt-repository ppa:ondrej/php
    sudo apt update
    sudo apt install php8.2,php8.2-cli,php-8.2{bz2,curl,mbstring,intl} -y
    sudo apt install php8.2-{gd,dom,curl,bz2,mbstring,intl} -y

    # install compooser v2.x
    brew install composer
    ```

    > ビルド

    ```bash
    composer install --no-dev
    ```

2. docker ビルド

    ```bash
    docker build -t gekal/drupal:10.0-apache .
    ```

## 動作確認

```bash
docker run --name some-drupal -p 18080:80 -d gekal/drupal:10.0-apache
# http://localhost:18080/
```

## Docker Compose 環境

1. 起動

    > <http://localhost/>

    ```bash
    sudo chown 33:33 -R drupal/web
    docker-compose up -d
    # 初期起動の場合、「キャッシュをクリア」を実施したほうがいいと思います。
    ```

2. 停止・クリア

    ```bash
    docker-compose down

    # Docker のキャッシュをクリアする。
    docker system prune -f
    docker volume prune -f
    ```

## 環境バックアップ（初回のみ）

1. 必要なツールをインストール（初回のみ）

    ```bash
    docker exec drupal-web apt-get update
    docker exec drupal-web apt-get install zip -y
    ```

2. コンテナー中のファイルを外出し

    ```bash
    # 対象フォルダを圧縮する。
    docker exec drupal-web zip -r default.zip web/sites/default

    # フォルダを作成する。
    mkdir -p ./drupal/

    # コンテナーからローカルに圧縮ファイルをコピーする。
    docker cp drupal-web:/var/www/html/default.zip ./drupal

    # 圧縮ファイルを解凍する。
    unzip ./drupal/default.zip -d ./drupal/

    # 不要な圧縮ファイルを削除する。
    rm ./drupal/*.zip
    ```

## DBへの接続

<http://localhost:880/?server=db&username=drupal&db=drupal>

> パスワード: `password`

## テストアカウント

<http://localhost/>

| ユーザー | パスワード |
| -------- | ---------- |
| gekal    | 123456     |

## デバッグ実施

下記手順でContainerのローカルにデバッグを実施できます。

1. `Visual Studio Code`と`Dev Containers`プラグインをインストールする。
2. `drupal-web`にアタッチする。 -> Dev Containers: Attach to Running Container...

    Open Folder: /opt/drupal

3. リモート側には、`PHP Debug`プラグインをインストールする。
4. `F5`でデバッグを開始する。
