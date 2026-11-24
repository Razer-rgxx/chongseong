# 들판 날씨 (2026-11-24)

들판에서만 흐르는 날씨 다섯 가지와, 날씨마다 작은 사건 하나. 언덕·마을·무덤에는 없다. 규칙은 `Rules`, 화면은 `WeatherFx`·`WeatherProps`·`field.gd`.

## 정한 것

- 날씨: 맑음 `clear`, 비 `rain`, 안개 `fog`, 폭풍 `storm`(비 + 번개 + 낮은 천둥), 잿바람 `ash`(떠도는 재·불똥, 따뜻한 안개).
- 새벽(낮 가중치 `FieldLayout.WEATHER_DAY`)과 해질녘(밤 가중치 `WEATHER_NIGHT`)에만 `Rules.rng`로 다시 굴린다(`_roll_weather`). 다른 날씨로 바뀌면 신호 `field_weather_changed(kind)`.
- 상태: `Rules.field_weather`(+ 사건 자리 `weather_spots`), `state_hash`에 든다. `Meta.field_weather`·`weather_spots`에 시계처럼 저장하고(들판을 떠날 때) 이어 간다. 옛 저장은 맑음.
- 화면: 날씨마다 안개 짙기·해 밝기·물들임(`FieldLayout.WX_LOOK`)을 8초에 걸쳐 섞는다. 입자는 카메라를 따라다니는 GPUParticles3D(비·재·불똥)라 싸고, 웹은 `WebQuality.WEATHER_KEEP`(35%)만 남긴다. 바뀔 때 아래 띠에 한 줄("비가 내린다"). 세계에 글자는 없다.
- 폭풍의 번개는 꾸밈용 랜덤(6~14초마다): 흰 기둥·불빛·화면 번쩍임, 멀수록 늦게 낮은 쿵(`thump` 느린 높이). 종소리·올라가는 소리 없음.

## 날씨마다 사건 (자리는 `GLINTS` 칸 + `WX_OFFSET`, 보상은 `WX_REWARD`, 한 번만 준다 = `Rules.use_weather_spot`)

| 날씨 | 사건 |
| --- | --- |
| 비 | 젖은 쇳조각 자리 2곳이 더 선다(E로 조각) |
| 안개 | 길 잃은 순례자 한 사람. E로 말을 걸면 조각과 한 줄(마을 문까지 데려가기는 만들지 않았다) |
| 폭풍 | 벼락 맞은 검이 서고 번개가 친다. E로 거두면 조각 + 쇠 재료 |
| 맑은 밤 | 비석마다 한 줄 더(`STONE_NIGHT_LINES`). 반딧불이가 줄지어 가리키는 숨은 상자(맑은 밤에만, E로 조각) |
| 잿바람 | 영주 곁에 불씨 땅이 5초마다 2곳(12단계 `embers`·`_tick_embers`와 같은 피해). 쓰지 않은 철 자리가 2곳 더 선다(`Meta.ash_iron`) |

사건 자리는 새벽·해질녘마다(날씨가 그대로여도) 새로 정해지고, 줍지 않은 것은 사라진다.

## 시험

`tests/weather_tests.gd`: 낮에는 안 바뀜, 다섯 날씨가 다 나옴, 같은 시드 = 같은 해시, 날씨별 사건이 서고 한 번만 줌, 불씨 땅이 닿으면 닳음, 비석 한 줄, 저장 왕복.
