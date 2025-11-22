# MygramDB::Client - MygramDB用Perlクライアント

[MygramDB](https://github.com/libraz/mygram-db)用のPerlクライアントライブラリです。MygramDBは、MySQLレプリケーション機能を持つ高性能インメモリ全文検索エンジンです。

## 特徴

- **デュアル実装**: Pure PerlとXS (Cバインディング) の両方を提供
- **完全なプロトコルサポート**: すべてのMygramDBコマンド (SEARCH, COUNT, GET, INFO等) に対応
- **Unicodeサポート**: CJKや絵文字を含む完全なUTF-8サポート
- **簡単インストール**: Makefile.PLを使った標準的なCPAN形式のインストール
- **高性能**: XS版は5-10倍の性能向上を実現
- **単独動作**: 埋め込みソースから外部依存なしでビルド可能

## クイックスタート

```bash
# 1. ビルドとインストール (埋め込みソースが同梱済み)
perl Makefile.PL
make
make test
sudo make install

# 2. コードで使用
perl -e 'use MygramDB::Client; print "準備完了!\n"'
```

完全な動作例は [examples/simple.pl](examples/simple.pl) を参照してください。

## インストール

### 前提条件

**最小要件:**
- Perl 5.14 以降
- make

**XSモジュール用 (オプション、高性能化のため):**
- C++コンパイラ (g++, clang++)
- MygramDBソース (埋め込みビルド用) または libmygramclient (システムビルド用)

### ビルドモード

このディストリビューションには MygramDB クライアントソースが埋め込まれており、外部依存なしで単独ビルドが可能です。ビルドシステムは自動的に最適なオプションを検出します：

1. **埋め込みソース** (デフォルト - 同梱済み)
   ```bash
   perl Makefile.PL  # 検出: "Using embedded libmygramclient source"
   make
   ```
   - ✅ 外部依存なし
   - ✅ 完全に自己完結
   - ✅ すぐに使える

2. **システムライブラリ** (オプション - MygramDBがインストール済みの場合)
   ```bash
   # システム全体にMygramDBがインストール済みの場合
   perl Makefile.PL  # 検出: "Found libmygramclient at: /usr/local"
   make
   ```
   - システムインストール済みのlibmygramclientを使用
   - より新しいバージョンの可能性

3. **Pure Perlのみ** (コンパイラ不要)
   ```bash
   # C++コンパイラが利用できない場合
   perl Makefile.PL  # "XS module will not be built"
   make
   ```
   - ✅ コンパイラ不要
   - ✅ どのプラットフォームでも動作
   - 性能は劣るが完全に機能

### 標準インストール

```bash
perl Makefile.PL
make
make test
sudo make install
```

### インストール確認

```bash
# Pure Perl版の確認
perl -MMygramDB::Client -e 'print "Pure Perl: OK\n"'

# XS版の確認 (ビルドされている場合)
perl -MMygramDB::Client::XS -e 'print "XS: OK\n"'
```

## 使い方

### Pure Perl版

```perl
use MygramDB::Client;

my $client = MygramDB::Client->new(
    host    => 'localhost',
    port    => 11016,
    timeout => 5,
);

$client->connect() or die $client->errstr;

# シンプルな検索
my $result = $client->search(
    table => 'articles',
    query => 'hello world',
    limit => 100,
);

print "検索結果: $result->{total_count}件\n";
for my $doc (@{$result->{results}}) {
    print "  - $doc->{primary_key}\n";
}

# AND/NOT条件とフィルタを使った高度な検索
my $result2 = $client->search(
    table      => 'articles',
    query      => 'technology',
    and_terms  => ['AI', 'machine learning'],  # これらを含む必須
    not_terms  => ['old', 'deprecated'],        # これらを含まない
    filters    => { status => 1, category => 'tech' },  # フィールドフィルタ
    sort_column => 'created_at',
    sort_desc  => 1,  # 降順
    limit      => 50,
);

# マッチするドキュメント数を取得
my $count = $client->count(
    table => 'articles',
    query => 'hello',
);
print "合計: $count件\n";

# プライマリキーでドキュメントを取得
my $doc = $client->get(
    table       => 'articles',
    primary_key => '12345',
);
print "タイトル: $doc->{fields}{title}\n";

$client->disconnect();
```

### ユーザー検索クエリのパース

Pure PerlとXS版の両方で、Web風の検索式のパースをサポート:

```perl
use MygramDB::Client;

# Google検索のようなユーザー入力をパース
my $parsed = MygramDB::Client->parse_search_expression('+golang -old "web framework"');

# 返り値:
# {
#   main_term      => 'golang',
#   and_terms      => [],
#   not_terms      => ['old'],
#   optional_terms => ['web framework']
# }

# パース結果を検索に使用
my $client = MygramDB::Client->new(host => 'localhost', port => 11016);
$client->connect();

my $result = $client->search(
    table      => 'articles',
    query      => $parsed->{main_term},
    and_terms  => $parsed->{and_terms},
    not_terms  => $parsed->{not_terms},
    limit      => 100,
);
```

パーサーがサポートする構文:
- `+term` - 必須キーワード (AND)
- `-term` - 除外キーワード (NOT)
- `"phrase"` - 引用符フレーズ
- `OR` - 論理OR演算子
- `()` - グルーピング (XS版はネイティブC++パーサーを使用)

### XS版 (高性能)

```perl
use MygramDB::Client::XS;

my $client = MygramDB::Client::XS->new(
    'localhost',  # host
    11016,        # port
    5000,         # timeout_ms
    65536,        # recv_buffer_size
);

$client->connect();

# シンプルな検索
my $result = $client->search(
    'articles',  # table
    'hello',     # query
    100,         # limit
    0,           # offset
);

# フィルタ付き高度な検索
my $result2 = $client->search_advanced(
    'articles',       # table
    'technology',     # query
    50,               # limit
    0,                # offset
    ['AI'],           # AND条件
    ['old'],          # NOT条件
    {status => 1},    # フィルタ
    'created_at',     # ソート列
    1,                # 降順
);

$client->disconnect();
```

## サンプル

`examples/` ディレクトリに以下のサンプルがあります:

- `simple.pl` - Pure Perl版の基本的な使い方
- `xs_example.pl` - XS版の使い方
- `benchmark.pl` - Pure PerlとXS版の性能比較

## APIリファレンス

### コンストラクタオプション (Pure Perl)

- `host` - サーバーホスト名 (デフォルト: "127.0.0.1")
- `port` - サーバーポート (デフォルト: 11016)
- `timeout` - 接続タイムアウト秒数 (デフォルト: 5)
- `recv_buffer_size` - 受信バッファサイズ (デフォルト: 65536)

### XSコンストラクタ

```perl
MygramDB::Client::XS->new($host, $port, $timeout_ms, $recv_buffer_size)
```

### メソッド

#### 接続

- `connect()` - サーバーに接続
- `disconnect()` - サーバーから切断
- `is_connected()` - 接続状態を確認

#### 検索操作

- `search(%options)` - ドキュメント検索
  - **table** (必須) - テーブル名
  - **query** (必須) - 検索クエリテキスト
  - **limit** (オプション、デフォルト: 1000) - 最大結果数
  - **offset** (オプション、デフォルト: 0) - ページネーション用オフセット
  - **and_terms** (オプション) - 必須キーワードの配列 (すべて一致必須)
  - **not_terms** (オプション) - 除外キーワードの配列 (いずれも一致しない)
  - **filters** (オプション) - フィールドフィルタのハッシュ (例: `{status => 1}`)
  - **sort_column** (オプション) - ソート用列名
  - **sort_desc** (オプション、デフォルト: 1) - 降順 (1) または 昇順 (0)

- `count(%options)` - マッチするドキュメント数をカウント
  - **table** (必須) - テーブル名
  - **query** (必須) - 検索クエリテキスト

- `get(%options)` - プライマリキーでドキュメント取得
  - **table** (必須) - テーブル名
  - **primary_key** (必須) - ドキュメントのプライマリキー

#### サーバー操作

- `info()` - サーバー情報を取得
- `sync(%options)` - スナップショット同期をトリガー
- `replication_status()` - レプリケーションステータスを取得

#### デバッグ

- `enable_debug()` - デバッグモードを有効化
- `disable_debug()` - デバッグモードを無効化

#### ユーティリティ

- `parse_search_expression($expression)` - Web風検索式をパース (クラスメソッド)
  - **expression** (必須) - Web風検索文字列 (例: `"+golang -old tutorial"`)
  - 返り値のハッシュ:
    - **main_term** - メイン検索キーワード
    - **and_terms** - 必須キーワードの配列
    - **not_terms** - 除外キーワードの配列
    - **optional_terms** - オプショナルキーワードの配列

#### 低レベル

- `send_command($command)` - 生コマンドを送信 (Pure Perlのみ)

## パフォーマンス

ベンチマーク結果 (100回検索):

```
Pure Perl: 100検索を0.523秒で実行 (平均: 0.00523秒)
XS:        100検索を0.091秒で実行 (平均: 0.00091秒)

XSはPure Perlより5.75倍高速
```

## テスト

テストの実行:

```bash
make test
```

**注意:** 基本テストはサーバー不要で実行可能。高度なテストには `localhost:11016` で動作するMygramDBが必要です。

テスト用MygramDBの起動:

```bash
docker run -d --name mygramdb \
  -p 11016:11016 \
  -e MYSQL_HOST=your-mysql-host \
  -e MYSQL_USER=repl_user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_DATABASE=mydb \
  -e TABLE_NAME=articles \
  -e TABLE_PRIMARY_KEY=id \
  -e TABLE_TEXT_COLUMN=content \
  ghcr.io/libraz/mygram-db:latest

# データを初期化
docker exec mygramdb mygram-cli -p 11016 SYNC articles
```

## トラブルシューティング

### XSモジュールがビルドできない

**libmygramclientが利用可能か確認:**
```bash
ls /usr/local/include/mygramdb/
ls /usr/local/lib/libmygramclient.*
```

**埋め込みソースビルドを試す:**
```bash
./embed-source.sh ../mygram-db
perl Makefile.PL
make
```

### macOSのコンパイル問題

"cstring file not found" などのC++ヘッダーエラーが出る場合:

```bash
# ビルドシステムがSDKパスを自動検出するはずです
# 失敗する場合はXcodeインストールを確認:
xcode-select --install
xcrun --show-sdk-path
```

### 実行時にライブラリが見つからない (macOS)

```bash
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

バンドルライブラリの場合、ビルドシステムが自動的にrpathを設定します。

### テストが失敗する

MygramDBサーバーが起動してアクセス可能か確認:
```bash
telnet localhost 11016
```

## 配布

配布用tarballの作成:

```bash
make dist
```

これにより `MygramDB-Client-X.XX.tar.gz` が作成され、CPANまたは直接配布できます。

CPANへのアップロード:
```bash
cpan-upload MygramDB-Client-0.01.tar.gz
```

## ライセンス

MIT License

## 作者

libraz <libraz@libraz.net>

## 関連項目

- [MygramDB](https://github.com/libraz/mygram-db) - MygramDBプロジェクト
- [プロトコルドキュメント](https://github.com/libraz/mygram-db/blob/main/docs/en/protocol.md)
- [クライアントライブラリドキュメント](https://github.com/libraz/mygram-db/blob/main/docs/en/libmygramclient.md)
