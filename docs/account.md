# 이메일 계정 (2026-11-24, 기능팀)

GD-Sync 계정 API(`account_create/login/verify/login_from_session/logout`)를 감싼 `Account`(scripts/net/account.gd)와 시작 화면의 로그인 창 `AccountWindow`(scripts/ui/account_window.gd, UiKit 모양).

- 창: 이메일·비밀번호(가려짐), 로그인, 가입(닉네임 칸이 생김), 인증 코드(인증이 필요할 때만 칸과 "코드 다시 받기"), 게스트로 하기, 상태 줄. 로그인했거나 게스트를 고른 적이 있으면 안 뜬다. 저장된 이메일이 있으면 먼저 저장된 세션으로 조용히 자동 로그인하고 안 되면 연다.
- 키·연결이 없어도 열린다. 그때는 "GD-Sync 키가 없습니다" 같은 짧은 한국어 오류만 띄우고 게스트로 계속할 수 있다(응답 번호 → 글은 `Account.message`).
- 저장: `user://account.cfg`에 이메일·닉네임·게스트 여부만. **비밀번호는 어디에도 저장하지 않는다.** 세션 토큰은 GD-Sync 플러그인이 제 키로 암호화해 `user://GD-Sync/`에 둔다.
- 로그아웃/로그인하기: 설정 창(`SettingsPanel`)의 "계정" 칸. 로그인하면 닉네임이 온라인 결투의 내 이름(`DuelHud.set_online`).
- 관리자: 로그인 세션이 인증한 이메일(플러그인 `login_email`)의 SHA-256(소문자·앞뒤 공백 제거)이 `Account.ADMIN_HASHES`에 있으면 `Account.admin`. 이메일 글은 저장소에 없다. 저장하지 않고 로그인마다 다시 정한다. 관리자는 어디서나 검 콘솔(` / F6, `AdminHost`)을 열고, 콘솔에 "날씨 비·안개·폭풍·잿바람·맑음"(`Rules.set_weather`, 들판에서만), "재료 쇠 50", "머리 망루"(`AdminCmd`)를 더한다. 어떤 순위에도 올리지 않는다(`FallenShare.may_submit`). 시작 화면에 "관리자" 표.

## GD-Sync 대시보드에서 할 일
1. 프로젝트의 User Accounts(계정)를 켠다.
2. 이메일 인증을 쓰려면 그 설정에서 켜고 메일 보내기를 맞춘다(안 켜면 가입하자마자 로그인된다). 켜면 인증 코드 칸이 쓰인다.
3. 키는 `user://gdsync_keys.cfg`(결투와 같은 것).
- 참고: 마을 입장 때 `FallenShare`가 따로 만드는 자동 계정(lordxxxxxx)은 이 계정과 별개다. 이메일 인증을 켜면 그 자동 계정 로그인이 막혀 "다른 영주의 검"이 조용히 빠진다(순위표 `fallen_swords`).
