fluent-plugin-gcm
=================

GCMへメッセージを送るためのアウトプットプラグインです。

GCMサーバから返された結果は入力されたタグ名に `.gcm.result` を付与したタグ名で再度 emit します。

利用方法
--------------------

設定サンプル
####################

```
<match notify.gcm.*>
  type gcm

  api_key starwars3

  flush_interval 10s
</match>
```

結果のタグ名はデフォルトで .gcm.result がサフィックスとなりますが、指定もできます。

```
<match notify.gcm.*>
  type gcm

  api_key starwars3
  app_name myapp

  result_tag_prefix result.
  result_tag_suffix .error

  flush_interval 10s
</match>
```


入力
#####################

- http://www.techdoctranslator.com/android/guide/google/gcm/adv 

```
@fluent_logger.log({
                      "registration_id" => [ "abc", "efg" ], 
                      "body" => { 
                          "collapse_key" => "get_new_item",
                          "delay_while_idle" => true,
                          "data" => { 
                              "message" => "hello world" 
                          },
                          "time_to_live" => 2
                      }
                   })
```

出力
#####################

処理結果は 1 registration_id を1 レコードとして fluentd のエンジンに再 emit することで行います。

```
{
  "status_code" => 200,
  "app_name" => "hogehoge",
  "error" => (response),
  "registration_id" => 1,
  "send_registration_id" => 1
}
```


```
# 接続自体に失敗したケース
{
  "status_code" => 500,
  "app_name" => "hogehoge",
  "error" => (response),
  "registration_id => [ 1, 2, 3.]"
}
```

TODO: 
------------------------------------

内部で https://github.com/spacialdb/gcm に依存していますが、送信ごとのセッション管理ではなくプラグインインスタンスの生存時間に合わせてコントロールした方がよさそう。

処理結果を出力方法をもうちょっと整理する。

ログ出力とエラー処理をもうちょっと分かりやすく。

送信失敗した registration_id に対して送信制御を内部で行ってもいいかもしれない。




