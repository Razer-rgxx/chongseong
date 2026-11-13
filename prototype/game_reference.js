const INS={"날":["피해 +N%",[10,13,17,22,32,46]],"가벼움":["휘두르기 속도 +N%",[8,10,14,18,26,37]],"긴 날":["사거리 +N%",[8,10,14,18,26,37]],"넓은 날":["베는 각도 +N%",[10,13,17,22,32,46]],"출혈":["벤 적이 3초 동안 N 피해를 더 입음",[6,8,10,13,19,28]],"처형":["체력 30% 이하인 적에게 피해 +N%",[20,26,34,44,64,92]],"연격":["마지막 타 피해 +N%",[20,26,34,44,64,92]],"밀쳐내기":["넉백 +N%",[20,26,34,44,64,92]],"무거움":["큰 베기 피해 +N%, 속도 -10%",[25,32,42,55,80,115]],"꿰뚫기":["적을 N명 더 꿰뚫음",[1,1,1,2,2,3]],"불씨":["N% 확률로 불을 붙임 (2초, 옆 적에게 번짐)",[8,10,14,18,26,37]],"서리":["벤 적이 N초 동안 30% 느려짐",[0.5,0.7,0.8,1.1,1.6,2.3]],"번개":["N번째 타격마다 근처 적 3명에게 번개",[8,7,6,5,4,3]],"흡혈":["준 피해의 N%만큼 체력 회복",[2,3,3,4,6,9]],"사냥":["적을 쓰러뜨리면 체력 +N",[2,3,3,4,6,9]],"광기":["체력이 낮을수록 피해 +최대 N%",[25,32,42,55,80,115]],"첫 타":["처음 베는 적에게 피해 +N%",[30,39,51,66,96,138]],"등 뒤":["적의 등 뒤를 베면 피해 +N%",[30,39,51,66,96,138]],"돌진 베기":["돌진으로 지나간 적에게 N 피해",[10,13,17,22,32,46]],"날랜 발":["돌진 재사용 시간 -N%",[10,13,17,22,32,46]],"단단함":["내구 +N%",[15,20,26,33,48,69]],"숫돌":["적을 쓰러뜨리면 내구 +N",[1,1,2,2,3,5]],"막기":["휘두르는 동안 받는 피해 -N%",[10,13,17,22,32,46]],"가시":["나를 때린 적에게 N 피해",[5,6,8,11,16,23]],"버팀":["받는 피해 -N%",[5,6,8,11,16,23]],"잔상":["N% 확률로 한 번 더 벰",[6,8,10,13,19,28]],"바꿔 쥐기":["이 검으로 바꿔 쥔 뒤 첫 공격 피해 +N%",[40,52,68,88,128,184]],"무리 베기":["한 번에 셋 이상 베면 피해 +N%",[20,26,34,44,64,92]],"거인 베기":["큰 적에게 피해 +N%",[20,26,34,44,64,92]],"망령 베기":["망령에게 피해 +N%",[25,32,42,55,80,115]],"마지막 일격":["부러질 때 둘레 2칸에 N 피해",[30,39,51,66,96,138]],"가벼운 손":["들고 있으면 낮에 뽑을 때 체력을 N 덜 씀",[1,1,2,2,3,4]],"행운":["들고 있으면 낮 뽑기 운 +N%",[5,6,8,11,16,23]],"피의 값":["휘두를 때마다 체력 1을 쓰고 피해 +N%",[30,39,51,66,96,138]],"새벽":["밤의 마지막 30초 동안 피해 +N%",[30,39,51,66,96,138]],"투박함":["피해 -10%, 내구 +N%",[40,52,68,88,128,184]]};
const SW=[["녹슨 단검",0,0,["투박함"],"",""],["녹슨 장검",0,1,["투박함"],"",""],["녹슨 대검",0,2,["투박함"],"",""],["녹슨 세검",0,3,["투박함"],"",""],["이 빠진 단검",0,0,["출혈"],"",""],["이 빠진 장검",0,1,["출혈"],"",""],["이 빠진 대검",0,2,["출혈"],"",""],["이 빠진 세검",0,3,["출혈"],"",""],["농부의 단검",0,0,["사냥"],"",""],["농부의 장검",0,1,["사냥"],"",""],["농부의 대검",0,2,["사냥"],"",""],["농부의 세검",0,3,["사냥"],"",""],["병사의 단검",0,0,["단단함"],"",""],["병사의 장검",0,1,["단단함"],"",""],["병사의 대검",0,2,["단단함"],"",""],["병사의 세검",0,3,["단단함"],"",""],["훈련용 단검",0,0,["밀쳐내기"],"",""],["훈련용 장검",0,1,["밀쳐내기"],"",""],["훈련용 대검",0,2,["밀쳐내기"],"",""],["훈련용 세검",0,3,["밀쳐내기"],"",""],["가벼운 단검",0,0,["가벼움"],"",""],["가벼운 장검",0,1,["가벼움"],"",""],["가벼운 대검",0,2,["가벼움"],"",""],["가벼운 세검",0,3,["가벼움"],"",""],["무거운 단검",0,0,["무거움"],"",""],["무거운 장검",0,1,["무거움"],"",""],["무거운 대검",0,2,["무거움"],"",""],["무거운 세검",0,3,["무거움"],"",""],["긴 장검",0,1,["긴 날"],"",""],["긴 대검",0,2,["긴 날"],"",""],["긴 세검",0,3,["긴 날"],"",""],["넓적한 단검",0,0,["넓은 날"],"",""],["넓적한 장검",0,1,["넓은 날"],"",""],["넓적한 대검",0,2,["넓은 날"],"",""],["날 선 단검",0,0,["날"],"",""],["날 선 장검",0,1,["날"],"",""],["날 선 대검",0,2,["날"],"",""],["날 선 세검",0,3,["날"],"",""],["순찰병의 단검",0,0,["날랜 발"],"",""],["순찰병의 장검",0,1,["날랜 발"],"",""],["순찰병의 대검",0,2,["날랜 발"],"",""],["순찰병의 세검",0,3,["날랜 발"],"",""],["사냥꾼의 단검",0,0,["등 뒤"],"",""],["사냥꾼의 장검",0,1,["등 뒤"],"",""],["사냥꾼의 대검",0,2,["등 뒤"],"",""],["사냥꾼의 세검",0,3,["등 뒤"],"",""],["대장간 시험작 단검",0,0,["숫돌"],"",""],["대장간 시험작 장검",0,1,["숫돌"],"",""],["대장간 시험작 대검",0,2,["숫돌"],"",""],["대장간 시험작 세검",0,3,["숫돌"],"",""],["이름 없는 단검",0,0,["행운"],"",""],["이름 없는 장검",0,1,["행운"],"",""],["이름 없는 대검",0,2,["행운"],"",""],["이름 없는 세검",0,3,["행운"],"",""],["진흙 묻은 단검",0,0,["버팀"],"",""],["진흙 묻은 장검",0,1,["버팀"],"",""],["진흙 묻은 대검",0,2,["버팀"],"",""],["진흙 묻은 세검",0,3,["버팀"],"",""],["휜 단검",0,0,["잔상"],"",""],["휜 장검",0,1,["잔상"],"",""],["휜 대검",0,2,["잔상"],"",""],["휜 세검",0,3,["잔상"],"",""],["결투용 단검",0,0,["첫 타"],"",""],["결투용 장검",0,1,["첫 타"],"",""],["결투용 대검",0,2,["첫 타"],"",""],["결투용 세검",0,3,["첫 타"],"",""],["방패병의 단검",0,0,["막기"],"",""],["방패병의 장검",0,1,["막기"],"",""],["방패병의 대검",0,2,["막기"],"",""],["방패병의 세검",0,3,["막기"],"",""],["가시 돋친 단검",0,0,["가시"],"",""],["가시 돋친 장검",0,1,["가시"],"",""],["가시 돋친 대검",0,2,["가시"],"",""],["가시 돋친 세검",0,3,["가시"],"",""],["피 묻은 단검",0,0,["흡혈"],"",""],["피 묻은 장검",0,1,["흡혈"],"",""],["피 묻은 대검",0,2,["흡혈"],"",""],["피 묻은 세검",0,3,["흡혈"],"",""],["마부의 단검",0,0,["돌진 베기"],"",""],["마부의 장검",0,1,["돌진 베기"],"",""],["마부의 대검",0,2,["돌진 베기"],"",""],["마부의 세검",0,3,["돌진 베기"],"",""],["성문 파수병의 단검",1,0,["막기"],"",""],["성문 파수병의 장검",1,1,["막기"],"",""],["성문 파수병의 대검",1,2,["막기"],"",""],["성문 파수병의 세검",1,3,["막기"],"",""],["기마대의 단검",1,0,["돌진 베기"],"",""],["기마대의 장검",1,1,["돌진 베기"],"",""],["기마대의 대검",1,2,["돌진 베기"],"",""],["기마대의 세검",1,3,["돌진 베기"],"",""],["궁정 결투가의 단검",1,0,["첫 타"],"",""],["궁정 결투가의 장검",1,1,["첫 타"],"",""],["궁정 결투가의 대검",1,2,["첫 타"],"",""],["궁정 결투가의 세검",1,3,["첫 타"],"",""],["처형인의 단검",1,0,["처형"],"",""],["처형인의 장검",1,1,["처형"],"",""],["처형인의 대검",1,2,["처형"],"",""],["처형인의 세검",1,3,["처형"],"",""],["북방 용병의 단검",1,0,["서리"],"",""],["북방 용병의 장검",1,1,["서리"],"",""],["북방 용병의 대검",1,2,["서리"],"",""],["북방 용병의 세검",1,3,["서리"],"",""],["봉화지기의 단검",1,0,["불씨"],"",""],["봉화지기의 장검",1,1,["불씨"],"",""],["봉화지기의 대검",1,2,["불씨"],"",""],["봉화지기의 세검",1,3,["불씨"],"",""],["사냥개 조련사의 단검",1,0,["출혈"],"",""],["사냥개 조련사의 장검",1,1,["출혈"],"",""],["사냥개 조련사의 대검",1,2,["출혈"],"",""],["사냥개 조련사의 세검",1,3,["출혈"],"",""],["무덤지기의 단검",1,0,["망령 베기"],"",""],["무덤지기의 장검",1,1,["망령 베기"],"",""],["무덤지기의 대검",1,2,["망령 베기"],"",""],["무덤지기의 세검",1,3,["망령 베기"],"",""],["공성병의 단검",1,0,["거인 베기"],"",""],["공성병의 장검",1,1,["거인 베기"],"",""],["공성병의 대검",1,2,["거인 베기"],"",""],["광전사의 단검",1,0,["광기"],"",""],["광전사의 장검",1,1,["광기"],"",""],["광전사의 대검",1,2,["광기"],"",""],["척후병의 단검",1,0,["등 뒤"],"",""],["척후병의 장검",1,1,["등 뒤"],"",""],["척후병의 대검",1,2,["등 뒤"],"",""],["척후병의 세검",1,3,["등 뒤"],"",""],["대장장이의 단검",1,0,["단단함"],"",""],["대장장이의 장검",1,1,["단단함"],"",""],["대장장이의 대검",1,2,["단단함"],"",""],["대장장이의 세검",1,3,["단단함"],"",""],["기수의 단검",1,0,["무리 베기"],"",""],["기수의 장검",1,1,["무리 베기"],"",""],["기수의 대검",1,2,["무리 베기"],"",""],["기수의 세검",1,3,["무리 베기"],"",""],["탈영병의 단검",1,0,["날랜 발"],"",""],["탈영병의 장검",1,1,["날랜 발"],"",""],["탈영병의 대검",1,2,["날랜 발"],"",""],["탈영병의 세검",1,3,["날랜 발"],"",""],["순례자의 단검",1,0,["사냥"],"",""],["순례자의 장검",1,1,["사냥"],"",""],["순례자의 대검",1,2,["사냥"],"",""],["순례자의 세검",1,3,["사냥"],"",""],["쌍검사의 단검",1,0,["바꿔 쥐기"],"",""],["쌍검사의 장검",1,1,["바꿔 쥐기"],"",""],["쌍검사의 대검",1,2,["바꿔 쥐기"],"",""],["쌍검사의 세검",1,3,["바꿔 쥐기"],"",""],["폭풍 기사단의 단검",1,0,["번개"],"",""],["폭풍 기사단의 장검",1,1,["번개"],"",""],["폭풍 기사단의 대검",1,2,["번개"],"",""],["폭풍 기사단의 세검",1,3,["번개"],"",""],["노병의 단검",1,0,["연격"],"",""],["노병의 장검",1,1,["연격"],"",""],["노병의 대검",1,2,["연격"],"",""],["노병의 세검",1,3,["연격"],"",""],["회색 서약",2,1,["버팀"],"",""],["늑대 송곳니",2,0,["출혈"],"",""],["마지막 파수",2,1,["막기"],"",""],["검은 개울",2,3,["꿰뚫기"],"",""],["까마귀 깃",2,0,["가벼움"],"",""],["무너진 성문",2,2,["거인 베기"],"",""],["겨울 숨",2,3,["서리"],"",""],["들불",2,1,["불씨"],"",""],["맹세 지킴이",2,1,["단단함"],"",""],["붉은 이삭",2,2,["무리 베기"],"",""],["밤바람",2,0,["날랜 발"],"",""],["첫눈",2,3,["첫 타"],"",""],["쇠사슬 끊개",2,2,["밀쳐내기"],"",""],["고요한 손",2,0,["등 뒤"],"",""],["천둥소리",2,2,["번개"],"",""],["피 젖은 깃발",2,1,["흡혈"],"",""],["늙은 사자",2,1,["연격"],"",""],["가시덤불",2,1,["가시"],"",""],["메아리",2,3,["잔상"],"",""],["곰의 앞발",2,2,["무거움"],"",""],["무덤 꽃",2,3,["망령 베기"],"",""],["굶주림",2,0,["사냥"],"",""],["갈림길",2,1,["바꿔 쥐기"],"",""],["망루의 눈",2,3,["긴 날"],"",""],["추수",2,2,["넓은 날"],"",""],["쇠 그림자",2,0,["잔상"],"",""],["동틀 녘",2,1,["새벽"],"",""],["마지막 한마디",2,0,["처형"],"",""],["붉은 송곳",2,3,["출혈"],"",""],["성난 황소",2,2,["돌진 베기"],"",""],["잿빛 매",2,3,["날랜 발"],"",""],["녹슨 왕관",2,1,["행운"],"",""],["핏값",2,2,["피의 값"],"",""],["부서진 맹세",2,1,["광기"],"",""],["개울 돌",2,0,["숫돌"],"",""],["산사태",2,2,["마지막 일격"],"",""],["얼어붙은 호수",2,2,["서리"],"",""],["여우 꼬리",2,0,["첫 타"],"",""],["빗장",2,1,["막기"],"",""],["다섯째 기사",2,1,["날"],"",""],["꺼진 등불",2,3,["망령 베기"],"",""],["장례 행렬",2,2,["무리 베기"],"",""],["바늘",2,3,["꿰뚫기"],"",""],["굽은 등",2,0,["가벼운 손"],"",""],["엉겅퀴",2,3,["가시"],"",""],["큰 짐승 사냥꾼",2,2,["거인 베기"],"",""],["봉화",2,1,["불씨"],"",""],["전령",2,0,["날랜 발"],"",""],["겨우살이",2,1,["흡혈"],"",""],["산지기",2,1,["사냥"],"",""],["깨진 투구",2,2,["버팀"],"",""],["새벽 닭",2,0,["새벽"],"",""],["빈 칼집",2,1,["바꿔 쥐기"],"",""],["독수리 발톱",2,0,["등 뒤"],"",""],["쓰러진 탑",2,2,["마지막 일격"],"",""],["왕의 그늘",3,1,["막기","버팀"],"",""],["일곱 상처",3,0,["출혈","연격"],"",""],["서리 왕관",3,2,["서리","거인 베기"],"",""],["불타는 들판",3,2,["불씨","무리 베기"],"",""],["백 번째 밤",3,1,["새벽","버팀"],"",""],["늑대 왕",3,0,["사냥","등 뒤"],"",""],["은빛 고삐",3,3,["돌진 베기","날랜 발"],"",""],["끝없는 행군",3,1,["단단함","숫돌"],"",""],["피의 군주",3,2,["흡혈","광기"],"",""],["처형대",3,2,["처형","무거움"],"",""],["바람의 길",3,3,["가벼움","잔상"],"",""],["망령 사냥꾼",3,1,["망령 베기","첫 타"],"",""],["천 개의 바늘",3,3,["꿰뚫기","잔상"],"",""],["폭풍의 맹세",3,1,["번개","연격"],"",""],["무너뜨리는 자",3,2,["밀쳐내기","거인 베기"],"",""],["가시 왕관",3,1,["가시","버팀"],"",""],["그림자 걸음",3,0,["날랜 발","등 뒤"],"",""],["겨울 늑대",3,0,["서리","출혈"],"",""],["마지막 기사단장",3,1,["날","막기"],"",""],["성벽",3,2,["막기","단단함"],"",""],["침묵",3,3,["첫 타","처형"],"",""],["쌍둥이 형제",3,0,["바꿔 쥐기","연격"],"",""],["핏빛 잔",3,0,["피의 값","흡혈"],"",""],["장작더미",3,2,["불씨","마지막 일격"],"",""],["우는 칼",3,3,["출혈","처형"],"",""],["무쇠 황소",3,2,["돌진 베기","밀쳐내기"],"",""],["끝없는 겨울바람",3,1,["서리","넓은 날"],"",""],["사냥의 여왕",3,3,["사냥","긴 날"],"",""],["맹세의 무덤",3,1,["망령 베기","행운"],"",""],["순례의 끝",3,1,["사냥","가벼운 손"],"",""],["대장장이 왕",3,2,["단단함","날"],"",""],["천둥새",3,3,["번개","가벼움"],"",""],["굶주린 땅",3,2,["흡혈","무리 베기"],"",""],["새벽 기사",3,1,["새벽","첫 타"],"",""],["독사",3,0,["출혈","잔상"],"",""],["깃발 없는 군대",3,1,["무리 베기","광기"],"",""],["탑지기",3,3,["긴 날","막기"],"",""],["잿더미 왕관",3,1,["불씨","행운"],"",""],["거인의 이빨",3,2,["거인 베기","마지막 일격"],"",""],["바위 심장",3,2,["버팀","가시"],"",""],["언덕의 첫 검",4,1,["단단함","행운"],"들고 있으면 낮에 뽑은 검의 내구가 20% 늘어난다.","이 언덕에 맨 처음 꽂힌 검. 다른 검들은 이 검을 따라 꽂혔다고 한다."],["되돌아오는 칼",4,0,["날랜 발","잔상"],"돌진하면 칼이 앞으로 날아갔다 돌아오며 길 위의 적을 벤다.","몇 번을 던져 버려도 아침이면 칼집에 돌아와 있었다."],["성주의 저울",4,1,["막기","날"],"체력이 절반 이상이면 피해 +40%, 절반 아래면 받는 피해 -40%.","성주는 이 검으로 재판을 했다. 이긴 쪽이 옳았다."],["백 명의 이름",4,2,["무리 베기","연격"],"그 밤에 쓰러뜨린 적 10마리마다 피해 +2% (최대 +60%).","칼날에 백 개의 이름이 새겨져 있다. 마지막 칸은 비어 있다."],["얼음 무덤",4,3,["서리","꿰뚫기"],"느려진 적을 찌르면 1.5초 얼어붙고, 언 적을 다시 베면 부서지며 둘레에 서리가 퍼진다.","북쪽 기사단이 통째로 얼어붙은 자리에서 나왔다."],["화형대",4,2,["불씨","넓은 날"],"불붙은 적이 쓰러지면 터져서 둘레 1.5칸에 불을 붙인다.","장작더미 속에서 녹지 않고 남았다."],["상처 세는 자",4,0,["출혈","가벼움"],"출혈 중인 적을 베면 남은 출혈 피해를 한꺼번에 준다.","주인은 자기가 낸 상처를 하나도 잊지 않았다."],["충신",4,1,["버팀","막기"],"체력이 0이 되면 이 검이 대신 부러지고 체력 30으로 버틴다 (밤마다 1번).","왕 대신 칼을 맞고 부러진 검. 누군가 다시 붙여 놓았다."],["무덤 파수",4,1,["망령 베기","사냥"],"쓰러뜨린 적의 30%가 내 편 망령으로 일어나 10초 동안 싸운다.","무덤지기가 평생 쓴 검. 무덤 속 사람들이 아직 그를 따른다."],["끌어당기는 손",4,3,["긴 날","첫 타"],"찌르기 끝에 맞은 적을 내 앞으로 끌어온다.","도망치는 적을 놓친 적이 없다."],["거인의 무릎",4,2,["거인 베기","무거움"],"큰 적을 세 번 연달아 베면 무릎을 꿇려 3초 동안 받는 피해가 2배가 된다.","거인 사냥꾼들은 늘 무릎부터 노렸다."],["쌍칼 서약",4,0,["바꿔 쥐기","연격"],"다른 칸에 든 검의 각인도 함께 발동한다.","형제 기사가 하나씩 나눠 들던 검. 혼자 들어도 둘이 싸운다."],["폭풍 부르는 자",4,1,["번개","연격"],"큰 베기가 땅을 쳐서 앞쪽 부채꼴로 번개가 퍼진다.","이 검을 뽑은 날마다 비가 왔다."],["굶주린 칼",4,2,["흡혈","숫돌"],"적을 쓰러뜨리면 내구가 닳지 않고 오히려 찬다. 10초 동안 아무도 못 베면 체력을 1씩 빨아먹는다.","베지 않으면 주인을 먹는다."],["바람 가르는 깃",4,3,["날랜 발","가벼움"],"돌진을 두 번 연달아 할 수 있다.","전령이 쓰던 칼. 소식보다 칼이 먼저 도착했다."],["마지막 숨",4,1,["광기","처형"],"체력이 20% 이하면 모든 공격이 큰 베기가 된다.","다 쓰러진 뒤에야 제 힘을 낸다."],["메아리 계곡",4,1,["잔상","넓은 날"],"휘두르고 0.5초 뒤 같은 자리에 같은 베기가 한 번 더 일어난다.","계곡에서 휘두르면 한 번 더 들린다고 해서 붙은 이름."],["핏빛 맹세",4,0,["피의 값","흡혈"],"큰 베기마다 체력 5를 쓰고 피해가 2배가 된다.","피로 맹세한 자만 쥘 수 있다."],["쇠말뚝",4,2,["밀쳐내기","막기"],"큰 베기 자리에 검 그림자가 꽂혀 4초 동안 적이 지나가지 못한다.","성벽이 무너진 날, 이 검 하나가 성문을 대신했다."],["행운의 녹",4,1,["행운","마지막 일격"],"이 검이 부러지면 다음 낮 첫 뽑기의 운이 3배가 된다.","녹이 슬수록 운이 좋아진다는 미신이 있다."],["새벽 나팔",4,1,["새벽","버팀"],"밤이 30초 남으면 체력을 모두 회복하고 피해 +50%.","밤새 버틴 병사들은 이 검이 빛나면 해가 뜬다는 걸 알았다."],["늪지기",4,3,["긴 날","사냥"],"찌른 자리에 2초 동안 늪이 생겨 적이 60% 느려진다.","늪을 지키던 자의 검. 칼끝이 늘 젖어 있다."],["산 자의 몫",4,1,["가벼운 손","사냥"],"적을 쓰러뜨리면 10% 확률로 낮 뽑기 한 번이 체력 없이 된다 (최대 3번 쌓임).","죽은 자의 검을 거두던 장의사의 검."],["모래시계",4,0,["날랜 발","등 뒤"],"돌진하면 1초 동안 둘레 적이 70% 느려진다.","이 칼에 베인 자는 모두 느리게 쓰러졌다고 한다."],["무너진 왕좌",4,2,["버팀","무리 베기"],"둘레 3칸 안의 적 하나마다 받는 피해 -5% (최대 -50%).","에워싸일수록 왕은 침착했다."],["언덕을 쌓은 검",4,2,["무거움","막기"],"큰 베기마다 앞에 흙벽이 솟아 5초 동안 적을 막는다 (벽 최대 3개).","땅을 갈라 이 언덕을 쌓아 올렸다는 검."],["첫 번째 왕",4,1,["날","버팀"],"들고 있는 두 검의 각인 수치가 50% 오른다.","첫 왕국의 왕이 들던 검. 그의 기사들은 이 검 앞에서 두 배로 싸웠다."],["끝나지 않는 겨울",4,3,["서리","꿰뚫기"],"밤 동안 눈이 내려 모든 적이 20% 느려지고, 찌른 적은 1초 얼어붙는다.","이 검이 뽑혀 있는 동안 언덕에 봄이 오지 않았다."],["대화재",4,2,["불씨","넓은 날"],"휘두른 자리에 3초 동안 불길이 남는다.","한 왕국을 사흘 동안 태운 불이 이 검에서 시작됐다."],["천 명의 기사",4,1,["연격","무리 베기"],"기사 망령 3명이 따라다니며 내 베기를 따라 벤다 (피해 30%).","언덕에 잠든 기사 천 명이 이 검의 주인을 따른다."],["구름 가르는 천둥",4,1,["번개","거인 베기"],"5번째 타격마다 가장 센 적 3명에게 벼락이 떨어진다 (피해 400%).","구름을 벤 자국이 아직 하늘에 남아 있다고 한다."],["피의 강",4,0,["출혈","흡혈"],"출혈로 쓰러진 적이 피 웅덩이를 남기고, 웅덩이를 밟으면 체력이 찬다.","언덕 아래 개울이 한때 붉었던 이유."],["멈춘 순간",4,0,["날랜 발","등 뒤"],"돌진하면 1.5초 동안 나만 빼고 모두 멈춘다 (재사용 12초).","이 검을 쥔 기사는 혼자 백 명을 베고도 숨이 차지 않았다."],["거인 왕의 뼈",4,2,["거인 베기","밀쳐내기"],"큰 적을 쓰러뜨리면 10초 동안 몸이 커져 피해와 사거리 +50%.","거인 왕의 갈비뼈를 갈아 만들었다."],["영원한 파수",4,1,["막기","흡혈"],"체력이 0이 되어도 10초 동안 쓰러지지 않고, 그동안 준 피해만큼 체력을 되찾는다 (밤마다 1번).","주인은 죽은 뒤에도 사흘을 더 성문을 지켰다."],["바람의 왕",4,3,["긴 날","꿰뚫기"],"찌르기가 바람이 되어 화면 끝까지 날아가며 모두 꿰뚫는다.","찌른 자리에서 바람이 시작된다."],["망자들의 왕관",4,1,["망령 베기","사냥"],"쓰러뜨린 적이 모두 내 편 망령으로 일어난다 (최대 8).","이 검 앞에서는 죽은 자도 무릎을 꿇는다."],["부러지지 않는 맹세",4,1,["단단함","무거움"],"이 검은 부러지지 않는다. 대신 휘두를수록 무거워져 속도가 줄고 피해가 는다.","천 번을 내리쳐도 부러지지 않았다. 대신 주인이 늙었다."],["마지막 장례",4,2,["마지막 일격","숫돌"],"다른 검이 부러지면 그 검의 각인 하나를 이 검이 가져간다 (그 판 동안, 최대 4개).","부러진 검들을 묻어 주던 검. 묻은 검들의 힘을 품고 있다."],["운명 베기",4,0,["행운","가벼운 손"],"낮에 뽑은 검이 마음에 안 들면 이 검의 내구 30을 써서 다시 뽑는다 (낮마다 3번).","운명이 마음에 들지 않으면 베어 버리라고, 주인은 말했다."],["언덕의 심장",5,2,["무리 베기","날"],"휘두를 때마다 언덕에 꽂힌 검 5자루가 땅에서 솟아 둘레 적을 찌른다.","언덕 한가운데 가장 깊이 꽂힌 검. 모든 검이 이 검을 둘러싸고 있다."],["그림자 왕",5,0,["날랜 발","잔상"],"돌진한 자리에 내 그림자가 남아 5초 동안 같이 싸운다 (최대 3).","왕은 한 번도 혼자 싸운 적이 없다. 그림자가 늘 함께였다."],["겨울의 끝",5,3,["서리","처형"],"언 적이 부서질 때마다 다음 찌르기가 화면 끝까지 닿는 얼음 창이 된다.","끝나지 않는 겨울을 끝낸 검."],["꺼지지 않는 불",5,2,["불씨","무거움"],"불이 꺼지지 않는다. 불붙은 적은 쓰러질 때까지 타며 옆으로 번진다.","꺼뜨린 사람이 아무도 없다."],["백 년 전쟁",5,1,["연격","버팀"],"밤이 깊을수록 강해진다. 10초마다 피해 +5% (상한 없음).","백 년 동안 한 번도 칼집에 들어가지 않았다."],["피의 왕좌",5,1,["흡혈","광기"],"흡혈로 체력이 넘치면 넘친 만큼 보호막이 된다 (최대 100).","왕좌에 오른 자는 피를 흘리지 않았다. 남의 피로 충분했다."],["떨어진 검",5,2,["거인 베기","마지막 일격"],"큰 베기 3번마다 하늘에서 거대한 검이 떨어져 둘레 4칸을 친다.","하늘에서 떨어졌다. 떨어진 자리에 아직 구덩이가 있다."],["망각",5,3,["첫 타","꿰뚫기"],"찔린 적은 나를 잊고 3초 동안 다른 적을 공격한다.","이 검에 베인 자는 자기가 누구와 싸우는지 잊는다."],["두 번째 기회",5,1,["버팀","행운"],"밤에 쓰러지면 그 밤을 처음부터 다시 한다 (판마다 1번).","주인은 같은 밤을 두 번 살았다고 한다."],["모든 검의 어머니",5,1,["행운","가벼운 손"],"들고 있으면 낮에 뽑는 모든 검이 각인을 하나 더 달고 나온다.","언덕의 검들은 모두 이 검에서 갈라져 나왔다."],["언덕",5,2,[],"부러지지 않는다. 들면 이 판에서 뽑은 모든 검의 각인이 함께 발동한다.","언덕이 검이고, 검이 언덕이다."],["처음이자 마지막 칼",5,1,[],"밤마다 한 번, 휘두르면 화면의 모든 적이 쓰러진다.","첫 전쟁을 시작한 칼이자, 마지막 전쟁을 끝낼 칼."],["이름을 잃은 검",5,0,[],"뽑는 순간 언덕의 모든 검이 함께 뽑혀 나와 도감이 다 채워진다.","아무도 이 검의 이름을 기억하지 못한다. 뽑은 사람도."]];
/* ===== 검의 언덕 시험판 =====
   낮: 언덕에 꽂힌 검을 뽑는다. 한 번 뽑을 때마다 체력이 준다. 밤: 뽑은 검으로 버틴다. 검은 벨수록 닳아 부러진다.
   다섯 구역을 올라 정상의 언덕지기를 쓰러뜨리면 끝. 죽으면 도감만 남는다. */
{
// ===================== [표] =====================
const GN = ['흔함', '귀함', '전설', '신화', '초월', '무한'], DT = [0, 1, 2, 3, 6, 7];      // DT: 등급 → 연출 데모의 단계
const ODDS = [1, 6, 40, 200, 2000, 50000], DM = [1, 1.25, 1.6, 2, 3, 5], DUR = [80, 110, 150, 200, 300, 450];
const GC = DT.map(t => TIERS[t].col), REVEAL = 2;                                          // 전설부터 큰 연출
const FN = ['단검', '장검', '대검', '세검'];
// 형태: 피해, 속도, 사거리, 각도, 내구, 연타 수, 넉백
const FM = [[0.7, 1.5, 0.8, 0.8, 0.8, 3, 0.7], [1, 1, 1, 1, 1, 3, 1], [1.7, 0.6, 1.3, 1.4, 1.3, 2, 1.8], [0.9, 1.2, 1.4, 0.4, 0.9, 3, 0.6]];
const ZONES = 10, T_NIGHT = 75, HP = 140, PULL = 10, HEAL = 50, HILTS = 16, AW = 34, AH = 22;
const ZN = ['기슭', '들머리', '비탈', '바위턱', '중턱', '안개 띠', '능선', '칼바람 마루', '봉우리 아래', '정상'];
const ZLUCK = [1, 1.3, 1.7, 2.2, 3, 4, 5, 6.5, 8, 10], ZHP = [1, 1.25, 1.5, 1.8, 2.2, 2.6, 3.1, 3.7, 4.4, 5.2], ZDMG = [1, 1.1, 1.2, 1.35, 1.5, 1.65, 1.8, 2, 2.2, 2.4];
const LORD = { spd: 4.3, dmg: 20, reach: 1.55, arc: 1.9, cd: 0.38, dashV: 13, dashT: 0.16, dashCd: 1.1 };
const EN = {
  wraith: { n: '망령', hp: 30, dmg: 6, spd: 1.6, r: 0.3, col: '#b9a8e8', cd: 1, wraith: 1 },
  wolf: { n: '늑대', hp: 16, dmg: 4, spd: 3, r: 0.26, col: '#c08a55', cd: 0.7 },
  giant: { n: '거인', hp: 200, dmg: 16, spd: 0.9, r: 0.62, col: '#7d8794', cd: 1.4, big: 1 },
  boss: { n: '언덕지기', hp: 2400, dmg: 26, spd: 1.25, r: 0.9, col: '#901425', cd: 1.2, big: 1, boss: 1 },
};
// 시험판에서 아직 작동하지 않는 고유 능력(수치와 각인은 그대로 적용된다)
const TODO = new Set(['되돌아오는 칼', '무덤 파수', '쇠말뚝', '늪지기', '언덕을 쌓은 검', '대화재', '천 명의 기사', '피의 강', '망자들의 왕관', '마지막 장례', '운명 베기', '그림자 왕', '겨울의 끝', '망각']);
SW.forEach(s => { if (s[5]) QUOTE[s[0]] = s[5]; });
const BYG = GN.map((_, g) => SW.map((s, i) => s[1] === g ? i : -1).filter(i => i >= 0));
DT.forEach((t, g) => { TIERS[t].items = BYG[g].map(i => SW[i][0]); });

// ===================== [상태] =====================
let G;
const rnd = Math.random, clamp = (v, a, b) => Math.max(a, Math.min(b, v)), TAU = Math.PI * 2;
function newRun() {
  G = { zone: 0, phase: 'day', hp: HP, shield: 0, x: AW / 2, y: AH / 2, face: -Math.PI / 2, cd: 0, combo: 0, comboT: 0, swing: 0, big: false, dash: 0, dx: 0, dy: -1, dashCh: 1, dashRe: 0, dashHit: null, inv: 0,
    sw: [null, null], act: 0, en: [], fx: [], nums: [], hilts: [], pull: null, pend: null, choice: null, tN: 0, spawnT: 0, bossOut: false, kills: 0, nKills: 0, pulls: 0, best: 0, hitN: 0, bigN: 0, walk: 0, mv: false, thN: 0, swap: false,
    shake: 0, hitstop: 0, flash: null, stopT: 0, stopCd: 0, luck3: false, free: 0, runIns: {}, used: {}, nUsed: {}, starve: 0, oath: 0, giantT: 0, undying: 0, snap: null, t: 0, over: null,
    dbg: { force: -1, god: false, ts: 1 } };
  $('td').classList.remove('ov', 'ch'); newDay();
}
function newDay() {
  G.phase = 'day'; G.en = []; G.hilts = []; G.x = AW / 2; G.y = AH / 2; G.camSnap = true;
  for (let i = 0; i < HILTS; i++) { let x, y, k = 0; do { x = 2 + rnd() * (AW - 4); y = 2 + rnd() * (AH - 4); } while (k++ < 40 && (Math.hypot(x - G.x, y - G.y) < 2.5 || G.hilts.some(h => Math.hypot(h.x - x, h.y - y) < 2.2))); G.hilts.push({ x, y, a: (rnd() - 0.5) * 0.5 }); }
  say((G.zone + 1) + '구역 ' + ZN[G.zone] + '. 검 앞에서 E를 눌러 뽑아. 한 번에 체력 ' + PULL + '. 준비되면 N으로 밤을 맞아.');
}
const mk = i => { const d = SW[i], g = d[1], ins = {}; d[3].forEach(k => ins[k] = INS[k][1][g]); const max = d[0] === '부러지지 않는 맹세' || d[0] === '언덕' || d[1] === 5 && !d[3].length ? Infinity : Math.round(DUR[g] * FM[d[2]][4] * (1 + ((ins['단단함'] || 0) + (ins['투박함'] || 0)) / 100)); return { i, n: d[0], g, f: d[2], ins, u: d[4], dur: max, max }; };
const cur = () => G.sw[G.act], other = () => G.sw[1 - G.act];
const U = n => { const s = cur(); return !!s && s.n === n; };          // 지금 쥔 검이 그 검인가
const H = n => G.sw.some(s => s && s.n === n);                          // 두 칸 중 어디든 들고 있는가
// 지금 쥔 검의 각인 값. 쌍칼 서약, 언덕, 첫 번째 왕을 반영한다
function I(k) {
  const s = cur(); if (!s) return 0; let v = s.ins[k] || 0;
  if (s.n === '쌍칼 서약' && other()) v = Math.max(v, other().ins[k] || 0);
  if (s.n === '언덕') v = Math.max(v, G.runIns[k] || 0);
  return v * (H('첫 번째 왕') ? 1.5 : 1);
}
const held = k => G.sw.reduce((a, s) => a + (s ? s.ins[k] || 0 : 0), 0) * (H('첫 번째 왕') ? 1.5 : 1);   // 들고만 있어도 되는 각인
const luck = () => ZLUCK[G.zone] * (1 + held('행운') / 100) * (G.luck3 ? 3 : 1);
const pullCost = () => Math.max(1, PULL - held('가벼운 손'));
function rollGrade() { if (G.dbg.force >= 0) return G.dbg.force; const l = luck(); for (let g = 5; g >= 1; g--) if (rnd() < l / ODDS[g]) return g; return 0; }

// ===================== [소리·알림] =====================
const sfx = f => { try { if (soundOn) f(); } catch (e) {} };
let lastHit = 0;
const hitSnd = v => { const n = performance.now(); if (n - lastHit < 45) return; lastHit = n; sfx(() => { tone('sine', 130, 50, 0.12, v); noise(0.06, v * 0.7, 2600, 400); }); };
let sayT = 0;
function say(t) { const e = $('toast'); e.textContent = t; e.classList.add('on'); sayT = 4.5; }
const num = (x, y, t, c, big, h) => G.nums.push({ x, y, t: String(t), c, big, h: h || 1.3, a: 0 });
const heal = v => { if (v <= 0 || G.hp <= 0) return; const over = G.hp + v - HP; G.hp = Math.min(HP, G.hp + v); if (over > 0 && U('피의 왕좌')) G.shield = Math.min(100, G.shield + over); };

// ===================== [낮: 뽑기] =====================
function tryPull() {
  if (G.phase !== 'day' || G.pull || G.choice) return;
  const h = G.hilts.find(h => !h.gone && Math.hypot(h.x - G.x, h.y - G.y) < 1.1); if (!h) return;
  const free = G.free > 0, cost = free ? 0 : pullCost();
  if (G.hp <= cost) return say('체력이 모자라. 더 뽑으면 쓰러져.');
  const g = rollGrade(); G.luck3 = false;
  G.pull = { h, g, t: 0, T: 0.45 + 0.42 * g, cost, free, step: 0 };
}
function stepPull(dt) {
  const p = G.pull; p.t += dt;
  const st = Math.min(p.g, Math.floor(p.t / 0.42));
  if (st > p.step) { p.step = st; G.shake = Math.max(G.shake, 0.12 + 0.07 * st); G.fx.push({ k: 'crack', x: p.h.x, y: p.h.y, t: 0, T: 1.2, s: st, a: rnd() * TAU }); sfx(() => { tone('sine', 92 - st * 8, 38, 0.4, 0.26 + 0.05 * st); noise(0.12, 0.12 + 0.03 * st, 900, 120); }); }
  if (p.t < p.T) return;
  G.pull = null; p.h.gone = true; if (p.free) G.free--; else G.hp -= p.cost; G.pulls++; G.best = Math.max(G.best, p.g);
  const list = BYG[p.g], sw = mk(list[(rnd() * list.length) | 0]);
  if (H('언덕의 첫 검') && isFinite(sw.max)) { sw.max = Math.round(sw.max * 1.2); sw.dur = sw.max; }
  if (H('모든 검의 어머니')) { const ks = Object.keys(INS).filter(k => !(k in sw.ins)); const k = ks[(rnd() * ks.length) | 0]; sw.ins[k] = INS[k][1][sw.g]; sw.extra = k; }
  for (const k in sw.ins) G.runIns[k] = Math.max(G.runIns[k] || 0, sw.ins[k]);
  G.fx.push({ k: 'burst', x: p.h.x, y: p.h.y, c: GC[p.g], t: 0, T: 0.6, n: 10 + p.g * 6 });
  if (p.g >= REVEAL) { G.pend = sw; play(DT[p.g], sw.n, false); if (S) return; G.pend = null; }
  else { rolls++; owned[sw.n] = (owned[sw.n] || 0) + 1; save(); sfx(() => { noise(0.12, 0.14, 2600, 500); tone('sine', 150, 80, 0.14, 0.2); }); G.flash = { c: GC[p.g], a: 0.08 + 0.08 * p.g }; }
  got(sw);
}
function got(sw) {
  if (sw.n === '이름을 잃은 검') { SW.forEach(s => owned[s[0]] = owned[s[0]] || 1); save(); say('언덕의 모든 검이 함께 뽑혀 나왔다. 도감이 다 채워졌어.'); }
  const k = G.sw.findIndex(s => !s);
  if (k >= 0) { G.sw[k] = sw; if (!cur()) G.act = k; say(GN[sw.g] + ' · ' + sw.n + '을(를) 뽑았어.'); drawCards(); return; }
  G.choice = sw; G.choiceAt = performance.now(); G.discardArm = 0; drawChoice();
}
// 연출은 화면을 누르면 끝나는데, 그 누름이 막 뜬 선택 창의 버튼에 그대로 들어가 검이 버려지곤 했다.
// 그래서 창이 뜬 뒤 0.6초는 누름을 받지 않고, 버리기는 두 번 눌러야 한다.
function choose(k) {
  const sw = G.choice; if (!sw) return;
  if (performance.now() - G.choiceAt < 800) return;
  if (k < 0 && !G.discardArm) { G.discardArm = 1; $('chX').innerHTML = '정말 버리기<kbd>X</kbd>'; $('chX').classList.add('warn'); return; }
  if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  G.choice = null; $('td').classList.remove('ch');
  if (k >= 0) { G.sw[k] = sw; say(sw.n + '을(를) ' + (k + 1) + '번 칸에 들었어.'); } else say(sw.n + '은(는) 두고 간다.');
  drawCards();
}

// ===================== [밤] =====================
function startNight() {
  if (G.phase !== 'day' || G.pull || G.choice || S) return;
  G.snap = JSON.stringify({ hp: G.hp, sw: G.sw, act: G.act, kills: G.kills }, (k, v) => v === Infinity ? 'INF' : v);
  G.phase = 'night'; G.tN = T_NIGHT; G.spawnT = 1.5; G.bossOut = false; G.nKills = 0; G.nUsed = {}; G.hilts = []; G.starve = 0; G.oath = 0; G.undying = 0; G.stopT = 0; G.shield = 0;
  say('밤이 왔다. ' + T_NIGHT + '초를 버텨.' + (G.zone === ZONES - 1 ? ' 정상의 언덕지기를 쓰러뜨려야 끝난다.' : '')); sfx(() => { tone('sine', 70, 40, 1.2, 0.3); noise(0.8, 0.12, 600, 80); });
}
function spawn(k, x, y) {
  const D = EN[k]; if (x === undefined) { const s = (rnd() * 4) | 0; x = s < 2 ? rnd() * AW : s === 2 ? -1 : AW + 1; y = s === 0 ? -1 : s === 1 ? AH + 1 : rnd() * AH; }
  const hp = D.hp * (D.boss ? 1 : ZHP[G.zone]);
  G.en.push({ k, D, x, y, hp, max: hp, cd: rnd() * 0.5, kx: 0, ky: 0, fx: 0, fy: 1, flash: 0, slowT: 0, slowK: 0, stun: 0, bleed: 0, bleedT: 0, burn: 0, knee: 0, vuln: 0 });
}
function stepNight(dt) {
  G.tN -= dt; const z = G.zone, prog = 1 - Math.max(0, G.tN) / T_NIGHT, last = z === ZONES - 1;
  if (last && !G.bossOut && G.tN <= T_NIGHT * 0.55) { G.bossOut = true; spawn('boss'); say('언덕지기가 올라온다.'); G.shake = 0.5; sfx(() => { tone('sine', 60, 30, 1.5, 0.4); noise(1, 0.2, 500, 60); }); }
  if ((G.spawnT -= dt) <= 0 && G.en.length < 70 && (G.tN > 0 || last)) {
    G.spawnT = (1.5 - 0.8 * Math.min(1, prog)) / (1 + 0.16 * z);
    const r = rnd(); spawn(z >= 1 && r < Math.min(0.25, 0.04 + 0.02 * z) && prog > 0.25 ? 'giant' : r < Math.min(0.55, 0.3 + 0.03 * z) ? 'wolf' : 'wraith');
  }
  if (G.tN <= 30 && H('새벽 나팔') && !G.nUsed.horn) { G.nUsed.horn = 1; G.hp = HP; say('새벽 나팔이 빛난다. 체력을 모두 되찾았어.'); G.flash = { c: '#ffe9a8', a: 0.4 }; }
  if (G.tN <= 0 && (!last || (G.bossOut && !G.en.some(e => e.D.boss)))) endNight();
}
function endNight() {
  for (const e of G.en) G.fx.push({ k: 'burst', x: e.x, y: e.y, c: '#ffe9a8', t: 0, T: 0.6, n: 5 }); G.en = [];
  if (G.zone === ZONES - 1) return finish(true);
  G.zone++; G.hp = Math.min(HP, G.hp + HEAL); G.flash = { c: '#ffe9a8', a: 0.35 }; newDay();
  say('날이 밝았다. 체력 +' + HEAL + '. ' + (G.zone + 1) + '구역 ' + ZN[G.zone] + '(으)로 올라왔어. 뽑기 운 ×' + ZLUCK[G.zone] + '.');
}
function finish(win) {
  G.phase = 'over'; G.over = { win };
  $('ovT').textContent = win ? '언덕의 정상에 섰다' : (G.zone + 1) + '구역에서 쓰러졌다';
  $('ovP').innerHTML = '뽑은 검 ' + G.pulls + '자루 · 쓰러뜨린 적 ' + G.kills + ' · 가장 높은 등급 <b style="color:' + GC[G.best] + '">' + GN[G.best] + '</b><br>도감 ' + SW.filter(s => owned[s[0]]).length + ' / ' + SW.length;
  $('td').classList.add('ov');
}

// ===================== [싸움] =====================
function stats() {
  const s = cur(), F = s ? FM[s.f] : [0.3, 1.2, 0.65, 0.8, 1, 3, 0.6], g = s ? s.g : 0;
  let dmg = LORD.dmg * F[0] * DM[g] * (1 + I('날') / 100) * (I('투박함') ? 0.9 : 1);
  let spd = F[1] * (1 + I('가벼움') / 100) * (I('무거움') ? 0.9 : 1);
  dmg *= 1 + I('광기') / 100 * (1 - G.hp / HP);
  if (G.phase === 'night' && G.tN <= 30) dmg *= 1 + I('새벽') / 100 + (G.nUsed.horn ? 0.5 : 0);
  if (I('피의 값')) dmg *= 1 + I('피의 값') / 100;
  if (U('성주의 저울') && G.hp >= HP / 2) dmg *= 1.4;
  if (U('백 명의 이름')) dmg *= 1 + Math.min(0.6, Math.floor(G.nKills / 10) * 0.02);
  if (U('백 년 전쟁') && G.phase === 'night') dmg *= 1 + 0.05 * Math.floor((T_NIGHT - G.tN) / 10);
  if (U('부러지지 않는 맹세')) { dmg *= 1 + Math.min(1.5, G.oath * 0.01); spd *= 1 - Math.min(0.45, G.oath * 0.003); }
  let reach = LORD.reach * F[2] * (1 + I('긴 날') / 100), arc = LORD.arc * F[3] * (1 + I('넓은 날') / 100);
  if (G.giantT > 0) { dmg *= 1.5; reach *= 1.5; }
  if (U('바람의 왕')) reach = 40;
  return { s, F, dmg, spd, reach, arc: Math.min(arc, TAU), pierce: s && s.f === 3 ? (U('바람의 왕') ? 999 : 2 + I('꿰뚫기')) : 999 };
}
const inArc = (e, x, y, face, reach, arc) => { const dx = e.x - x, dy = e.y - y, d = Math.hypot(dx, dy); if (d > reach + e.D.r) return false; let a = Math.atan2(dy, dx) - face; a = Math.atan2(Math.sin(a), Math.cos(a)); return Math.abs(a) <= arc / 2 || d <= e.D.r + 0.35; };
function attack() {
  if (G.cd > 0 || G.dash > 0) return;
  const st = stats(), s = st.s, len = st.F[5];
  if (G.comboT <= 0) G.combo = 0; G.combo = G.combo % len + 1; G.comboT = 0.9;
  const big = G.combo === len || (U('마지막 숨') && G.hp <= HP * 0.2);
  G.cd = LORD.cd / st.spd * (big ? 1.25 : 1); G.swing = 0.2; G.big = big; G.sArc = st.arc; G.sReach = Math.min(st.reach, 12);
  if (I('피의 값') && G.hp > 1) G.hp -= 1;
  if (U('부러지지 않는 맹세')) G.oath++;
  sfx(() => noise(0.09, big ? 0.12 : 0.07, big ? 1800 : 2600, 500));
  let dmg = st.dmg * (big ? 1.7 * (1 + I('무거움') / 100) * (1 + I('연격') / 100) : 1);
  if (G.swap) { dmg *= 1 + I('바꿔 쥐기') / 100; G.swap = false; }
  if (big && U('핏빛 맹세') && G.hp > 5) { G.hp -= 5; dmg *= 2; }
  if (U('처음이자 마지막 칼') && G.phase === 'night' && !G.nUsed.last) {
    G.nUsed.last = 1; G.flash = { c: '#ffffff', a: 0.8 }; G.shake = 0.6; sfx(() => { tone('sine', 80, 30, 1.2, 0.5); noise(0.8, 0.3, 2000, 100); });
    for (const e of [...G.en]) hurt(e, e.D.boss ? e.max * 0.5 : e.hp + 1, { big: true }); return;
  }
  let hit = G.en.filter(e => !e.dead && inArc(e, G.x, G.y, G.face, st.reach, st.arc)).sort((a, b) => Math.hypot(a.x - G.x, a.y - G.y) - Math.hypot(b.x - G.x, b.y - G.y)).slice(0, st.pierce);
  if (hit.length >= 3) dmg *= 1 + I('무리 베기') / 100;
  const knock = 0.38 * st.F[6] * (big ? 1.6 : 1) * (1 + I('밀쳐내기') / 100);
  for (const e of hit) strike(e, dmg, big, knock);
  if (U('메아리 계곡')) G.fx.push({ k: 'echo', x: G.x, y: G.y, face: G.face, reach: st.reach, arc: st.arc, dmg, big, t: 0, T: 0.5 });
  if (U('언덕의 심장')) for (const e of G.en.filter(e => !e.dead && Math.hypot(e.x - G.x, e.y - G.y) < 4.5).slice(0, 5)) { G.fx.push({ k: 'spike', x: e.x, y: e.y, t: 0, T: 0.4 }); hurt(e, dmg * 0.4, {}); }
  if (big && U('폭풍 부르는 자')) for (const e of G.en.filter(e => !e.dead && inArc(e, G.x, G.y, G.face, 5, 1.3))) zap(G.x, G.y, e, dmg * 0.8);
  if (hit.length) {
    if (big && U('떨어진 검') && ++G.bigN % 3 === 0) G.fx.push({ k: 'fall', x: G.x + Math.cos(G.face) * 1.5, y: G.y + Math.sin(G.face) * 1.5, dmg: dmg * 3, t: 0, T: 0.45 });
    G.hitstop = Math.max(G.hitstop, big ? 0.07 : 0.035); G.shake = Math.max(G.shake, big ? 0.32 : 0.14); hitSnd(big ? 0.35 : 0.22); G.starve = 0;
    if (s && isFinite(s.max) && !U('굶주린 칼')) { s.dur -= 1; if (s.dur <= 0) breakSword(G.act); }
  }
}
function strike(e, dmg, big, knock) {
  let d = dmg;
  if (e.hp <= e.max * 0.3) d *= 1 + I('처형') / 100;
  if (!e.wasHit) d *= 1 + I('첫 타') / 100;
  if ((e.x - G.x) * e.fx + (e.y - G.y) * e.fy > 0.3 * Math.hypot(e.x - G.x, e.y - G.y)) d *= 1 + I('등 뒤') / 100;
  if (e.D.big) d *= 1 + I('거인 베기') / 100;
  if (e.D.wraith) d *= 1 + I('망령 베기') / 100;
  if (e.vuln > 0) d *= 2;
  if (U('상처 세는 자') && e.bleedT > 0) { d += e.bleed * e.bleedT; e.bleedT = 0; }
  if (U('얼음 무덤')) { if (e.frozen) { e.frozen = false; e.stun = 0; d *= 1.5; G.fx.push({ k: 'ring', x: e.x, y: e.y, c: '#9fe8ff', r: 2, t: 0, T: 0.4 }); for (const o of G.en) if (o !== e && Math.hypot(o.x - e.x, o.y - e.y) < 2) slow(o, 0.3, 2); } else if (e.slowT > 0) { e.frozen = true; e.stun = Math.max(e.stun, 1.5); } }
  if (U('끝나지 않는 겨울')) e.stun = Math.max(e.stun, 1);
  if (U('거인의 무릎') && e.D.big && ++e.knee >= 3) { e.knee = 0; e.vuln = 3; e.stun = Math.max(e.stun, 1); }
  if (I('출혈')) { e.bleed = I('출혈') / 3; e.bleedT = 3; }
  if (I('불씨') && rnd() < I('불씨') / 100) e.burn = Math.max(e.burn, 2);
  if (I('서리')) slow(e, 0.3, I('서리'));
  if (U('끌어당기는 손')) { e.x = G.x + Math.cos(G.face) * 1.1; e.y = G.y + Math.sin(G.face) * 1.1; knock = 0; }
  const kd = Math.hypot(e.x - G.x, e.y - G.y) || 1;
  hurt(e, d, { big, kx: (e.x - G.x) / kd * knock, ky: (e.y - G.y) / kd * knock });
  heal(d * I('흡혈') / 100);
  if (I('잔상') && rnd() < I('잔상') / 100 && !e.dead) hurt(e, d, { c: '#cfd6e4' });
  if (I('번개') && ++G.hitN >= I('번개')) { G.hitN = 0; G.en.filter(o => !o.dead && o !== e).sort((a, b) => Math.hypot(a.x - e.x, a.y - e.y) - Math.hypot(b.x - e.x, b.y - e.y)).slice(0, 3).forEach(o => zap(e.x, e.y, o, d * 0.6)); }
  if (U('구름 가르는 천둥') && ++G.thN >= 5) { G.thN = 0; G.en.filter(o => !o.dead).sort((a, b) => b.hp - a.hp).slice(0, 3).forEach(o => zap(o.x, o.y, o, dmg * 4, true)); G.shake = 0.4; }
}
const slow = (e, k, t) => { e.slowK = Math.max(e.slowK, k); e.slowT = Math.max(e.slowT, t); };
function zap(x, y, e, d, sky) { G.fx.push({ k: 'zap', x, y, x2: e.x, y2: e.y, sky, t: 0, T: 0.18 }); hurt(e, d, { c: '#bfe6ff' }); }
function hurt(e, d, o) {
  if (e.dead) return; o = o || {}; if (G.undying > 0) heal(Math.min(d, e.hp)); e.hp -= d; e.wasHit = true; e.flash = 0.12;
  if (o.kx || o.ky) { const m = e.D.boss ? 0.2 : e.D.big ? 0.4 : 1; e.kx += (o.kx || 0) * m * 14; e.ky += (o.ky || 0) * m * 14; }
  num(e.x, e.y, Math.round(d), o.c || (o.big ? '#ffd76a' : '#ffffff'), o.big, e.D.r * 3 + 0.3);
  if (e.hp <= 0) kill(e);
}
function kill(e) {
  e.dead = true; G.kills++; G.nKills++; G.fx.push({ k: 'burst', x: e.x, y: e.y, c: e.D.col, t: 0, T: 0.5, n: e.D.big ? 16 : 7 });
  heal(I('사냥')); const s = cur();
  if (s && isFinite(s.max)) s.dur = Math.min(s.max, s.dur + I('숫돌') + (U('굶주린 칼') ? 3 : 0));
  if (e.burn > 0 && (U('화형대') || U('꺼지지 않는 불'))) { G.fx.push({ k: 'ring', x: e.x, y: e.y, c: '#ff8a3d', r: 1.5, t: 0, T: 0.35 }); for (const o of G.en) if (!o.dead && Math.hypot(o.x - e.x, o.y - e.y) < 1.5) o.burn = Math.max(o.burn, 2); }
  if (e.D.big && U('거인 왕의 뼈')) G.giantT = 10;
  if (H('산 자의 몫') && rnd() < 0.1 && G.free < 3) { G.free++; num(G.x, G.y, '공짜 뽑기 +1', '#9dffb0', false, 1.5); }
  if (e.D.boss) { G.shake = 0.7; G.flash = { c: '#ffffff', a: 0.6 }; sfx(() => { tone('sine', 70, 28, 1.6, 0.5); noise(1.2, 0.3, 1800, 80); }); }
}
function breakSword(k) {
  const s = G.sw[k]; if (!s) return; G.sw[k] = null;
  sfx(() => { noise(0.28, 0.3, 3200, 200); tone('square', 220, 60, 0.2, 0.12); }); G.shake = Math.max(G.shake, 0.3);
  G.fx.push({ k: 'burst', x: G.x, y: G.y, c: '#cfd6e4', t: 0, T: 0.6, n: 14 });
  const v = (s.ins['마지막 일격'] || 0) * (H('첫 번째 왕') ? 1.5 : 1);
  if (v) { G.fx.push({ k: 'ring', x: G.x, y: G.y, c: GC[s.g], r: 2, t: 0, T: 0.4 }); for (const e of [...G.en]) if (Math.hypot(e.x - G.x, e.y - G.y) < 2 + e.D.r) hurt(e, v, { big: true }); }
  if (s.n === '행운의 녹') { G.luck3 = true; say('행운의 녹이 부러졌다. 다음 뽑기의 운이 3배야.'); } else say(s.n + '이(가) 부러졌다.' + (G.sw[1 - k] ? '' : ' 이제 맨손이야.'));
  if (k === G.act && G.sw[1 - k]) { G.act = 1 - k; G.swap = true; }
  drawCards();
}
function swap() { if (G.sw[1 - G.act]) { G.act = 1 - G.act; G.swap = true; G.combo = 0; sfx(() => noise(0.05, 0.08, 1800, 900)); drawCards(); } }
function dashCdT() { return LORD.dashCd * (1 - Math.min(0.8, I('날랜 발') / 100)); }
function dash(mx, my) {
  if (G.dash > 0 || G.dashCh <= 0) return;
  const m = Math.hypot(mx, my); if (m > 0.1) { G.dx = mx / m; G.dy = my / m; } else { G.dx = Math.cos(G.face); G.dy = Math.sin(G.face); }
  G.dashCh--; if (G.dashRe <= 0) G.dashRe = dashCdT(); G.dash = LORD.dashT; G.dashHit = new Set(); G.inv = Math.max(G.inv, LORD.dashT + 0.05);
  sfx(() => noise(0.12, 0.1, 1400, 300));
  if (U('모래시계')) for (const e of G.en) if (Math.hypot(e.x - G.x, e.y - G.y) < 3.5) slow(e, 0.7, 1);
  if (U('멈춘 순간') && G.stopCd <= 0) { G.stopT = 1.5; G.stopCd = 12; G.flash = { c: '#9fd0ff', a: 0.25 }; }
}
function hitLord(d, e) {
  if (G.inv > 0 || G.dash > 0 || G.dbg.god || G.phase !== 'night') return;
  d *= (1 - Math.min(0.8, I('버팀') / 100)) * (G.swing > 0 ? 1 - Math.min(0.8, I('막기') / 100) : 1);
  if (U('성주의 저울') && G.hp < HP / 2) d *= 0.6;
  if (U('무너진 왕좌')) d *= 1 - Math.min(0.5, 0.05 * G.en.filter(o => Math.hypot(o.x - G.x, o.y - G.y) < 3).length);
  if (G.shield > 0) { const a = Math.min(G.shield, d); G.shield -= a; d -= a; }
  G.hp -= d; G.inv = 0.3; G.shake = Math.max(G.shake, 0.25); G.flash = { c: '#ff3040', a: 0.22 }; num(G.x, G.y, '-' + Math.round(d), '#ff6b6b', false, 1.3);
  sfx(() => tone('sawtooth', 150, 70, 0.14, 0.14));
  if (e && I('가시')) hurt(e, I('가시'), { c: '#c9ffb0' });
  if (G.hp > 0) return;
  if (G.undying > 0) { G.hp = 1; return; }
  const loyal = G.sw.findIndex(s => s && s.n === '충신');
  if (loyal >= 0 && !G.nUsed.loyal) { G.nUsed.loyal = 1; G.hp = 30; G.inv = 1.5; breakSword(loyal); return say('충신이 대신 부러졌다.'); }
  if (H('영원한 파수') && !G.nUsed.eternal) { G.nUsed.eternal = 1; G.undying = 10; G.hp = 1; return say('영원한 파수: 10초 동안 쓰러지지 않는다. 벤 만큼 체력을 되찾아.'); }
  if (H('두 번째 기회') && !G.used.second) { G.used.second = 1; const sn = JSON.parse(G.snap, (k, v) => v === 'INF' ? Infinity : v); G.hp = sn.hp; G.sw = sn.sw; G.act = sn.act; G.en = []; G.phase = 'day'; startNight(); drawCards(); return say('두 번째 기회: 이 밤을 처음부터 다시 한다.'); }
  G.hp = 0; finish(false);
}

// ===================== [갱신] =====================
function update(dt, inp) {
  G.t += dt;
  if (G.phase === 'over' || G.choice) return;
  if (G.pull) { stepPull(dt); stepFx(dt); return; }
  // 영주
  G.cd -= dt; G.comboT -= dt; G.swing -= dt; G.inv -= dt; G.stopCd -= dt; G.giantT -= dt;
  if (G.dashRe > 0 && (G.dashRe -= dt) <= 0) { const mx = U('바람 가르는 깃') ? 2 : 1; if (G.dashCh < mx) { G.dashCh++; if (G.dashCh < mx) G.dashRe = dashCdT(); } }
  if (inp.aim) G.face = Math.atan2(inp.aim.y - G.y, inp.aim.x - G.x);
  if (G.dash > 0) {
    G.dash -= dt; G.x += G.dx * LORD.dashV * dt; G.y += G.dy * LORD.dashV * dt; G.fx.push({ k: 'ghost', x: G.x, y: G.y, t: 0, T: 0.2 });
    const v = I('돌진 베기'); if (v) for (const e of G.en) if (!e.dead && !G.dashHit.has(e) && Math.hypot(e.x - G.x, e.y - G.y) < 0.8 + e.D.r) { G.dashHit.add(e); hurt(e, v, { c: '#ffe9a8' }); }
  } else {
    const m = Math.hypot(inp.x, inp.y), k = G.swing > 0 ? 0.55 : 1; G.mv = m > 0.1; if (G.mv) G.walk += dt * 11;
    if (m > 0.1) { G.x += inp.x / Math.max(1, m) * LORD.spd * k * dt; G.y += inp.y / Math.max(1, m) * LORD.spd * k * dt; if (!inp.aim) G.face = Math.atan2(inp.y, inp.x); }
  }
  G.x = clamp(G.x, 0.5, AW - 0.5); G.y = clamp(G.y, 0.5, AH - 0.5);
  if (inp.dash) dash(inp.x, inp.y);
  if (inp.atk && G.phase === 'night') attack();
  if (G.phase === 'night') {
    if (G.undying > 0 && (G.undying -= dt) <= 0 && G.hp <= 1) { G.undying = 0; G.hp = 0; return finish(false); }
    if (U('굶주린 칼') && (G.starve += dt) > 10 && G.hp > 1) G.hp = Math.max(1, G.hp - dt);
    stepNight(dt); if (G.phase !== 'night') return;
    stepEnemies(dt);
  }
  stepFx(dt);
}
function stepEnemies(dt) {
  const stopped = G.stopT > 0; if (stopped) G.stopT -= dt;
  const winter = H('끝나지 않는 겨울') ? 0.8 : 1, forever = U('꺼지지 않는 불');
  for (const e of G.en) {
    if (e.dead) continue; e.flash -= dt; e.vuln -= dt;
    if (e.bleedT > 0) { e.bleedT -= dt; e.hp -= e.bleed * dt; if (e.hp <= 0) { kill(e); continue; } }
    if (e.burn > 0) { if (!forever) e.burn -= dt; e.hp -= (6 + 5 * (cur() ? cur().g : 0)) * dt; if (rnd() < dt * 1.5) for (const o of G.en) if (o !== e && !o.dead && o.burn <= 0 && Math.hypot(o.x - e.x, o.y - e.y) < 1) { o.burn = 2; break; } if (e.hp <= 0) { kill(e); continue; } }
    e.x += e.kx * dt; e.y += e.ky * dt; e.kx *= Math.pow(0.001, dt); e.ky *= Math.pow(0.001, dt);
    if (stopped) continue;
    if (e.stun > 0) { e.stun -= dt; if (e.stun <= 0) e.frozen = false; continue; }
    if (e.slowT > 0) { e.slowT -= dt; if (e.slowT <= 0) e.slowK = 0; }
    const dx = G.x - e.x, dy = G.y - e.y, d = Math.hypot(dx, dy) || 1; e.fx = dx / d; e.fy = dy / d; e.cd -= dt;
    if (d > e.D.r + 0.42) { const v = e.D.spd * (1 - e.slowK) * winter * dt; e.x += e.fx * v; e.y += e.fy * v; }
    else if (e.cd <= 0) { e.cd = e.D.cd; hitLord(e.D.dmg * (e.D.boss ? 1 : ZDMG[G.zone]), e); }
  }
  for (let i = 0; i < G.en.length; i++) for (let j = i + 1; j < G.en.length; j++) {     // 서로 겹치지 않게
    const a = G.en[i], b = G.en[j], dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy), m = a.D.r + b.D.r;
    if (d < m && d > 1e-4) { const p = (m - d) / 2 / d; a.x -= dx * p; a.y -= dy * p; b.x += dx * p; b.y += dy * p; }
  }
  G.en = G.en.filter(e => !e.dead);
}
function stepFx(dt) {
  for (const f of G.fx) {
    f.t += dt; if (f.t < f.T) continue;
    if (f.k === 'echo') { G.swing = 0.15; G.sArc = f.arc; G.sReach = Math.min(f.reach, 12); const fa = G.face; for (const e of G.en) if (!e.dead && inArc(e, f.x, f.y, f.face, f.reach, f.arc)) hurt(e, f.dmg, { big: f.big, c: '#cfd6e4' }); G.face = fa; }
    if (f.k === 'fall') { G.shake = 0.6; G.fx.push({ k: 'ring', x: f.x, y: f.y, c: '#ffffff', r: 4, t: 0, T: 0.45 }); sfx(() => { tone('sine', 75, 30, 0.6, 0.45); noise(0.4, 0.3, 1500, 100); }); for (const e of [...G.en]) if (Math.hypot(e.x - f.x, e.y - f.y) < 4 + e.D.r) hurt(e, f.dmg, { big: true }); }
  }
  G.fx = G.fx.filter(f => f.t < f.T);
  for (const n of G.nums) n.a += dt; G.nums = G.nums.filter(n => n.a < 0.8);
}

// ===================== [화면] =====================
// 위에서 비스듬히 내려다보는 3/4 시점. 바닥(x, y)은 세로로 K만큼 눌러 그리고, 높이 z는 화면 위쪽으로 올린다.
// 고도에서는 카메라를 55°쯤 숙이면 같은 그림이 된다.
const cv = $('tdCv'), c = cv.getContext('2d'); let W = 0, Hh = 0, CELL = 40; const cam = { x: AW / 2, y: AH / 2 }, K = 0.62;
// 화면 크기는 캔버스가 실제로 차지한 크기로 잰다(폰·임베드에서 innerWidth와 다를 수 있다). 선명하게 그리려고 픽셀 밀도를 3까지 쓴다.
// SAFE: 체력·시간 표시, 검 카드, 터치 버튼에 가리지 않는 가운데 띠. 카메라는 영주를 이 띠 안에만 둔다.
let DPR = 0, SAFE = { t: 0, b: 0, cy: 0, h: 0 }, CY = 0, zoomKey = '', safeT = 0;
function measureSafe() {
  const vis = id => { const e = $(id); if (!e) return null; const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 ? r : null; };
  let t = 0, b = Hh;
  for (const id of ['hTC', 'hHP', 'hTR']) { const r = vis(id); if (r && r.top < Hh * 0.4) t = Math.max(t, r.bottom); }
  for (const id of ['cards', 'joy', 'tBtns']) { const r = vis(id); if (r && r.bottom > Hh * 0.55 && r.right > W * 0.3 && r.left < W * 0.7) b = Math.min(b, r.top); }   // 가운데를 가리는 것만 센다
  t += 6; b -= 6; if (b - t < Hh * 0.3) { t = 0; b = Hh; }
  SAFE = { t, b, cy: (t + b) / 2, h: b - t };
}
function layout() {
  const d = Math.min(3, devicePixelRatio || 1), r = $('td').getBoundingClientRect(), w = Math.round(r.width) || innerWidth, h = Math.round(r.height) || innerHeight;
  if (w !== W || h !== Hh || d !== DPR) { W = w; Hh = h; DPR = d; cv.width = Math.round(W * d); cv.height = Math.round(Hh * d); c.setTransform(d, 0, 0, d, 0, 0); }
  measureSafe();
  const key = W + 'x' + Hh + (touch ? 't' : '');
  if (key !== zoomKey) { zoomKey = key; CELL = clamp(Math.min(SAFE.h / (15 * K), W / 9), 30, 100); if (G) G.camSnap = true; }   // 띠 안에 바닥이 15칸쯤 보이게
}
const sx = x => (x - cam.x) * CELL + W / 2, sy = (y, z) => (y - cam.y) * CELL * K + CY - (z || 0) * CELL;
// 카메라: 영주를 띠 가운데에 두고 부드럽게 따라간다. 언덕 끝에서는 멈추되, 영주가 띠 밖으로 나가는 일은 없다.
function camStep(dt) {
  if ((safeT -= dt) <= 0) { safeT = 0.25; layout(); }
  const k = 1 - Math.exp(-dt * 8), snap = G.camSnap; G.camSnap = false;
  CY = snap ? SAFE.cy : CY + (SAFE.cy - CY) * k;
  const hw = W / 2 / CELL, hs = SAFE.h / 2 / (CELL * K);
  const fit = (t, lo, hi) => lo <= hi ? clamp(t, lo, hi) : (lo + hi) / 2;
  const tx = fit(G.x, hw - 1, AW - hw + 1), ty = fit(G.y - 0.4, hs - 1.5, AH - hs + 1.2);
  if (snap) { cam.x = tx; cam.y = ty; } else { cam.x += (tx - cam.x) * k; cam.y += (ty - cam.y) * k; }
  // 영주가 화면(띠) 밖으로 나가지 않게 붙잡는다
  const lo = G.y - (SAFE.b - 0.25 * CELL - CY) / (CELL * K), hi = G.y - (SAFE.t + 1.25 * CELL - CY) / (CELL * K);
  cam.x = clamp(cam.x, G.x - Math.max(0, hw - 0.6), G.x + Math.max(0, hw - 0.6));
  if (lo <= hi) cam.y = clamp(cam.y, lo, hi);
}
const pa = a => Math.atan2(Math.sin(a) * K, Math.cos(a));                       // 바닥 위의 방향 → 화면 위의 방향
const ell = (x, y, rx, ry) => { c.beginPath(); c.ellipse(x, y, Math.max(0.1, rx), Math.max(0.1, ry), 0, 0, TAU); c.fill(); };
const rr = (x, y, w, h, r) => { c.beginPath(); c.roundRect(x, y, w, Math.max(0.1, h), r); c.fill(); };
const GROUND = [['#3a4a31', '#31402a'], ['#404733', '#363c2b'], ['#474532', '#3c3a2b'], ['#4b463d', '#3f3b34'], ['#50505a', '#43434c']];
const OUT = ['#1a2016', '#1d2017', '#21201a', '#23211e', '#232329'];
const EDGE = ['#222b1c', '#272b1d', '#2c2a1f', '#2e2a25', '#2f2f37'];
function drawSword(x, y, ang, len, col, f, wide) {
  c.save(); c.translate(x, y); c.rotate(ang); c.lineCap = 'round';
  c.strokeStyle = '#3a2c20'; c.lineWidth = CELL * 0.09; c.beginPath(); c.moveTo(-CELL * 0.14, 0); c.lineTo(CELL * 0.08, 0); c.stroke();
  c.strokeStyle = col; c.lineWidth = CELL * 0.05; c.beginPath(); c.moveTo(CELL * 0.08, -CELL * 0.12); c.lineTo(CELL * 0.08, CELL * 0.12); c.stroke();
  c.strokeStyle = '#dfe6f0'; c.lineWidth = CELL * (wide || [0.05, 0.07, 0.13, 0.04][f]); c.beginPath(); c.moveTo(CELL * 0.1, 0); c.lineTo(len, 0); c.stroke();
  c.restore();
}
function drawHilt(h) {
  const p = G.pull && G.pull.h === h ? G.pull : null, k = p ? p.t / p.T : 0, jx = p ? (rnd() - 0.5) * (2 + p.step * 2.5) : 0, X = sx(h.x), Y = sy(h.y);
  c.fillStyle = 'rgba(0,0,0,.35)'; ell(X, Y, CELL * 0.2, CELL * 0.2 * K * 0.6);
  if (p && p.step > 0) { c.fillStyle = 'rgba(255,255,255,' + (0.05 + 0.04 * p.step) + ')'; ell(X, Y, CELL * (0.3 + 0.2 * p.step), CELL * (0.3 + 0.2 * p.step) * K); }
  c.save(); c.translate(X + jx, Y - k * CELL * 0.35); c.rotate(h.a); c.lineCap = 'round';
  c.strokeStyle = '#aeb6c2'; c.lineWidth = CELL * 0.07; c.beginPath(); c.moveTo(0, 0); c.lineTo(0, -CELL * (0.3 + 0.3 * k)); c.stroke();
  c.strokeStyle = '#6b5a45'; c.lineWidth = CELL * 0.06; c.beginPath(); c.moveTo(-CELL * 0.15, -CELL * (0.3 + 0.3 * k)); c.lineTo(CELL * 0.15, -CELL * (0.3 + 0.3 * k)); c.stroke();
  c.strokeStyle = '#3a2c20'; c.lineWidth = CELL * 0.08; c.beginPath(); c.moveTo(0, -CELL * (0.32 + 0.3 * k)); c.lineTo(0, -CELL * (0.55 + 0.3 * k)); c.stroke(); c.restore();
}
function drawLord() {
  const s = cur(), C = CELL * (G.giantT > 0 ? 1.4 : 1), X = sx(G.x), Y = sy(G.y), fx = Math.cos(G.face), fy = Math.sin(G.face), back = fy < -0.3;
  const red = G.inv > 0 && G.dash <= 0 && G.phase === 'night', step = G.mv ? Math.sin(G.walk) : 0, bob = Math.abs(step) * C * 0.03;
  let a = G.face + 0.7;
  if (G.swing > 0 && s) { const t = 1 - G.swing / 0.2; a = s.f === 3 ? G.face : G.face + (G.combo % 2 ? 1 : -1) * (G.sArc || 1.9) / 2 * (1 - 2 * t); }
  const sa = G.swing > 0 ? pa(a) : Math.atan2(Math.sin(a) * K + 0.6, Math.cos(a));       // 쉴 때는 칼끝이 땅 쪽
  const hx = X + Math.cos(a) * C * 0.22, hy = Y - C * 0.42 - bob + Math.sin(a) * C * 0.22 * K;
  const len = s ? C * [0.55, 0.85, 1.15, 1.05][s.f] * (s.f === 3 && G.swing > 0 ? 1.25 : 1) : 0;
  const behind = Math.sin(a) < -0.15, blade = () => { if (s) drawSword(hx, hy, sa, len, GC[s.g], s.f); c.fillStyle = '#f0d6b8'; ell(hx, hy, C * 0.05, C * 0.05); };
  c.fillStyle = 'rgba(0,0,0,.32)'; ell(X, Y, C * 0.3, C * 0.3 * K * 0.75);
  if (behind) blade();
  const l1 = Math.max(0, step) * C * 0.07, l2 = Math.max(0, -step) * C * 0.07;          // 다리
  c.fillStyle = '#3a3040'; rr(X - C * 0.13, Y - C * 0.22 - l1, C * 0.1, C * 0.2, 2); rr(X + C * 0.03, Y - C * 0.22 - l2, C * 0.1, C * 0.2, 2);
  c.fillStyle = '#7a2230';                                                                  // 망토
  if (back) rr(X - C * 0.22, Y - C * 0.7 - bob, C * 0.44, C * 0.6, C * 0.08); else rr(X - C * 0.22 - fx * C * 0.04, Y - C * 0.68 - bob, C * 0.44, C * 0.5, C * 0.08);
  if (!back) { c.fillStyle = red ? '#ffb0b0' : '#d9cdb4'; rr(X - C * 0.17, Y - C * 0.68 - bob, C * 0.34, C * 0.5, C * 0.1); c.fillStyle = '#5a4630'; c.fillRect(X - C * 0.17, Y - C * 0.34 - bob, C * 0.34, C * 0.05); }
  const HX = X + fx * C * 0.02, HY = Y - C * 0.86 - bob;                                   // 머리
  c.fillStyle = red ? '#ffc0b0' : '#f0d6b8'; ell(HX, HY, C * 0.17, C * 0.17);
  c.fillStyle = '#5a3a28';
  if (back) ell(HX, HY + C * 0.01, C * 0.17, C * 0.15);
  else { c.beginPath(); c.ellipse(HX, HY - C * 0.04, C * 0.17, C * 0.12, 0, Math.PI, TAU); c.fill(); c.fillStyle = '#2a1e18'; const ex = fx * C * 0.07; ell(HX + ex - C * 0.06, HY + C * 0.03, C * 0.024, C * 0.03); ell(HX + ex + C * 0.06, HY + C * 0.03, C * 0.024, C * 0.03); }
  c.fillStyle = '#e9b949'; c.beginPath(); [[-0.11, -0.12], [-0.11, -0.22], [-0.05, -0.16], [0, -0.25], [0.05, -0.16], [0.11, -0.22], [0.11, -0.12]].forEach(([u, v], i) => i ? c.lineTo(HX + u * C, HY + v * C) : c.moveTo(HX + u * C, HY + v * C)); c.fill();
  if (!behind) blade();
}
function drawEnemy(e) {
  const X = sx(e.x), Y = sy(e.y), R = e.D.r * CELL, fx = e.fx, fy = e.fy, back = fy < -0.3, w = Math.sin(G.t * 9 + e.x * 3);
  const col = e.flash > 0 ? '#ffffff' : e.frozen ? '#9fe8ff' : e.D.col;
  c.fillStyle = 'rgba(0,0,0,.3)'; ell(X, Y, R * 1.05, R * 0.42);
  if (e.slowT > 0 && !e.frozen) { c.strokeStyle = '#9fe8ff'; c.lineWidth = 2; c.beginPath(); c.ellipse(X, Y, R * 1.3, R * 1.3 * K, 0, 0, TAU); c.stroke(); }
  if (e.vuln > 0) { c.strokeStyle = '#ffd76a'; c.lineWidth = 3; c.beginPath(); c.ellipse(X, Y, R * 1.5, R * 1.5 * K, 0, 0, TAU); c.stroke(); }
  let top;
  if (e.k === 'wolf') {
    const L = R * 1.15, bx = fx * L, by = fy * L * K, dark = e.flash > 0 ? '#fff' : '#5e4128';
    const head = () => { const hx = X + bx * 0.8, hy = Y + by * 0.8 - R * 1.15; c.fillStyle = dark; c.beginPath(); c.moveTo(hx - R * 0.35, hy - R * 0.25); c.lineTo(hx - R * 0.22, hy - R * 0.7); c.lineTo(hx - R * 0.02, hy - R * 0.3); c.moveTo(hx + R * 0.35, hy - R * 0.25); c.lineTo(hx + R * 0.22, hy - R * 0.7); c.lineTo(hx + R * 0.02, hy - R * 0.3); c.fill(); c.fillStyle = col; ell(hx, hy, R * 0.46, R * 0.42); if (!back) { c.fillStyle = '#1a0e08'; ell(hx + fx * R * 0.2, hy + R * 0.18, R * 0.12, R * 0.09); c.fillStyle = '#ffe08a'; ell(hx + fx * R * 0.12 - R * 0.17, hy - R * 0.05, R * 0.07, R * 0.07); ell(hx + fx * R * 0.12 + R * 0.17, hy - R * 0.05, R * 0.07, R * 0.07); } };
    c.strokeStyle = dark; c.lineWidth = Math.max(2, R * 0.22); c.lineCap = 'round';
    for (const o of [-0.55, 0.55]) for (const sd of [-1, 1]) { const ox = X + bx * o * 0.75 + sd * R * 0.22, oy = Y + by * o * 0.75; c.beginPath(); c.moveTo(ox, oy - R * 0.8); c.lineTo(ox + w * sd * (o > 0 ? 1 : -1) * R * 0.22, oy); c.stroke(); }
    c.beginPath(); c.moveTo(X - bx * 0.75, Y - by * 0.75 - R); c.lineTo(X - bx * 1.15, Y - by * 1.15 - R * 1.35 - w * R * 0.1); c.stroke();      // 꼬리
    if (back) head();
    c.fillStyle = col; c.beginPath(); c.ellipse(X, Y - R * 0.95, Math.max(R * 0.55, Math.hypot(bx, by) * 0.85), R * 0.48, Math.atan2(by, bx), 0, TAU); c.fill();
    if (!back) head();
    top = Y - R * 2.2;
  } else if (e.k === 'wraith') {
    const fl = Math.sin(G.t * 2.5 + e.x) * R * 0.18, base = Y - R * 0.45 + fl, Ht = R * 2.9;
    c.globalAlpha = e.flash > 0 ? 1 : 0.88; c.fillStyle = col; c.beginPath(); c.moveTo(X - R * 0.85, base);
    for (let i = 1; i <= 4; i++) c.lineTo(X - R * 0.85 + i * R * 0.425, base + (i % 2 ? -R * 0.28 : 0) + Math.sin(G.t * 6 + i + e.y) * R * 0.08);
    c.quadraticCurveTo(X + R * 1.0, base - Ht * 0.75, X, base - Ht); c.quadraticCurveTo(X - R * 1.0, base - Ht * 0.75, X - R * 0.85, base); c.fill(); c.globalAlpha = 1;
    if (!back) { c.fillStyle = '#1a1030'; ell(X + fx * R * 0.22, base - Ht * 0.6, R * 0.42, R * 0.34); c.fillStyle = '#efe6ff'; ell(X + fx * R * 0.3 - R * 0.15, base - Ht * 0.6, R * 0.07, R * 0.09); ell(X + fx * R * 0.3 + R * 0.15, base - Ht * 0.6, R * 0.07, R * 0.09); }
    top = base - Ht;
  } else {
    const boss = !!e.D.boss, Hb = R * (boss ? 3.1 : 2.7), sw = w * R * 0.12, dk = e.flash > 0 ? '#fff' : boss ? '#4a0812' : '#454b55';
    c.fillStyle = dk; rr(X - R * 0.45, Y - R * 0.78 - Math.max(0, sw), R * 0.36, R * 0.78, R * 0.1); rr(X + R * 0.09, Y - R * 0.78 - Math.max(0, -sw), R * 0.36, R * 0.78, R * 0.1);
    rr(X - R * 0.98, Y - Hb * 0.8 - sw, R * 0.34, R * 1.35, R * 0.16); rr(X + R * 0.64, Y - Hb * 0.8 + sw, R * 0.34, R * 1.35, R * 0.16);
    c.fillStyle = col; rr(X - R * 0.72, Y - Hb * 0.86, R * 1.44, Hb * 0.62, R * 0.35);
    const HX = X + fx * R * 0.1, HY = Y - Hb * 0.93; ell(HX, HY, R * 0.38, R * 0.36);
    if (boss) { c.fillStyle = '#1a0306'; c.beginPath(); c.moveTo(HX - R * 0.3, HY - R * 0.15); c.lineTo(HX - R * 0.62, HY - R * 0.75); c.lineTo(HX - R * 0.12, HY - R * 0.3); c.moveTo(HX + R * 0.3, HY - R * 0.15); c.lineTo(HX + R * 0.62, HY - R * 0.75); c.lineTo(HX + R * 0.12, HY - R * 0.3); c.fill(); }
    if (!back) { c.fillStyle = boss ? '#ffcf5a' : '#1a1a1a'; ell(HX + fx * R * 0.12 - R * 0.13, HY, R * 0.07, R * 0.08); ell(HX + fx * R * 0.12 + R * 0.13, HY, R * 0.07, R * 0.08); }
    top = HY - R * (boss ? 0.8 : 0.45);
  }
  if (e.burn > 0) { c.fillStyle = 'rgba(255,140,40,.75)'; ell(X + (rnd() - 0.5) * R, top + R * (0.3 + rnd() * 0.4), R * 0.3, R * 0.38); }
  if (e.hp < e.max) { const bw = Math.max(24, R * 2.2); c.fillStyle = 'rgba(0,0,0,.6)'; c.fillRect(X - bw / 2, top - 9, bw, 4); c.fillStyle = e.D.boss ? '#ff4d6a' : '#ff8a6a'; c.fillRect(X - bw / 2, top - 9, bw * Math.max(0, e.hp / e.max), 4); }
}
function draw() {
  const night = G.phase === 'night' || (G.phase === 'over' && !G.over.win), z = G.zone, hw = W / 2 / CELL, hh = Hh / (CELL * K);
  const zc = Math.min(4, z >> 1); c.fillStyle = OUT[zc]; c.fillRect(0, 0, W, Hh);
  c.save(); if (G.shake > 0) c.translate((rnd() - 0.5) * G.shake * 22, (rnd() - 0.5) * G.shake * 22);
  { const x0 = Math.floor(cam.x - hw) - 2, x1 = Math.ceil(cam.x + hw) + 2, y0 = Math.floor(cam.y - hh) - 2, y1 = Math.ceil(cam.y + hh) + 3;   // 언덕 아래 땅의 돌과 풀
    for (let ix = x0; ix <= x1; ix++) for (let iy = y0; iy <= y1; iy++) { if (ix >= 0 && ix < AW && iy >= 0 && iy < AH) continue; const r = Math.abs(Math.sin(ix * 12.9898 + iy * 78.233) * 43758.5453) % 1; if (r > 0.16) continue;
      c.fillStyle = r < 0.05 ? 'rgba(0,0,0,.28)' : 'rgba(255,255,255,.035)'; ell(sx(ix + r * 4), sy(iy + r * 3), CELL * (0.18 + r * 2), CELL * (0.12 + r * 1.2) * K); } }
  // 언덕 윗면과 앞쪽 비탈
  const gx0 = sx(0), gy0 = sy(0), gw = AW * CELL, gh = AH * CELL * K;
  c.fillStyle = EDGE[zc]; c.fillRect(gx0, gy0 + gh, gw, CELL * 0.9);
  c.fillStyle = GROUND[zc][0]; c.fillRect(gx0, gy0, gw, gh);
  c.fillStyle = GROUND[zc][1]; for (let i = 0; i < 60; i++) { const px = (i * 7.31 + z * 3.7) % AW, py = (i * 4.73 + z * 1.9) % AH; ell(sx(px), sy(py), CELL * (0.5 + (i % 5) * 0.22), CELL * (0.32 + (i % 3) * 0.14) * K); }
  c.strokeStyle = 'rgba(0,0,0,.35)'; c.lineWidth = 3; c.strokeRect(gx0, gy0, gw, gh);
  // 바닥에 붙는 것
  for (const h of G.hilts) if (h.gone) { c.fillStyle = 'rgba(0,0,0,.45)'; ell(sx(h.x), sy(h.y), CELL * 0.12, CELL * 0.12 * K * 0.6); }
  for (const f of G.fx) { const k = f.t / f.T, X = sx(f.x), Y = sy(f.y);
    if (f.k === 'crack') { c.strokeStyle = 'rgba(10,8,6,' + (0.8 * (1 - k)) + ')'; c.lineWidth = 2; for (let i = 0; i < 3 + f.s; i++) { const a = f.a + i * 1.7, r = CELL * (0.5 + 0.35 * f.s) * Math.min(1, f.t * 6); c.beginPath(); c.moveTo(X, Y); c.lineTo(X + Math.cos(a + 0.3) * r * 0.5, Y + Math.sin(a + 0.3) * r * 0.5 * K); c.lineTo(X + Math.cos(a) * r, Y + Math.sin(a) * r * K); c.stroke(); } }
    if (f.k === 'ring') { c.strokeStyle = f.c; c.globalAlpha = 1 - k; c.lineWidth = 4; c.beginPath(); c.ellipse(X, Y, f.r * CELL * (0.3 + 0.7 * k), f.r * CELL * (0.3 + 0.7 * k) * K, 0, 0, TAU); c.stroke(); c.globalAlpha = 1; }
    if (f.k === 'fall') { c.fillStyle = 'rgba(255,255,255,' + 0.18 * k + ')'; ell(X, Y, 4 * CELL, 4 * CELL * K); }
    if (f.k === 'ghost') { c.fillStyle = 'rgba(200,220,255,' + 0.22 * (1 - k) + ')'; ell(X, Y - CELL * 0.45, CELL * 0.22, CELL * 0.45); }
  }
  if (G.swing > 0) { const X = sx(G.x), Y = sy(G.y), t = 1 - G.swing / 0.2, a = G.sArc || 1.9, r = (G.sReach || 1.55) * CELL;   // 베는 범위는 바닥에
    c.fillStyle = (G.big ? 'rgba(255,215,106,' : 'rgba(255,255,255,') + 0.32 * (1 - t) + ')'; c.beginPath(); c.moveTo(X, Y);
    for (let i = 0; i <= 18; i++) { const q = G.face - a / 2 + a * i / 18; c.lineTo(X + Math.cos(q) * r, Y + Math.sin(q) * r * K); } c.closePath(); c.fill(); }
  if (G.shield > 0 || G.undying > 0) { const X = sx(G.x), Y = sy(G.y); c.lineWidth = 3; c.strokeStyle = G.undying > 0 ? '#ffe9a8' : '#ff6b8a'; c.beginPath(); c.ellipse(X, Y, CELL * 0.5, CELL * 0.5 * K, 0, 0, TAU * (G.undying > 0 ? G.undying / 10 : G.shield / 100)); c.stroke(); }
  // 서 있는 것: 앞(화면 아래)에 있을수록 나중에 그린다
  const L = [];
  for (const h of G.hilts) if (!h.gone) L.push([h.y, () => drawHilt(h)]);
  for (const e of G.en) L.push([e.y, () => drawEnemy(e)]);
  L.push([G.y, drawLord]);
  for (const f of G.fx) if (f.k === 'spike') L.push([f.y, () => drawSword(sx(f.x), sy(f.y), -Math.PI / 2, CELL * 0.9 * Math.min(1, f.t / f.T * 3), '#ffd76a', 1)]);
  L.sort((a, b) => a[0] - b[0]).forEach(d => d[1]());
  // 공중
  for (const f of G.fx) { const k = f.t / f.T;
    if (f.k === 'fall') drawSword(sx(f.x), sy(f.y) - CELL * 2.2 - (1 - k) * Hh, Math.PI / 2, CELL * 2.2, '#fff', 2, 0.3);
    if (f.k === 'burst') { c.fillStyle = f.c; c.globalAlpha = 1 - k; const X = sx(f.x), Y = sy(f.y, 0.5); for (let i = 0; i < f.n; i++) { const a = i * 2.399 + f.x, r = CELL * (0.2 + 1.3 * k) * (0.5 + ((i * 37) % 10) / 10); c.fillRect(X + Math.cos(a) * r - 2, Y + Math.sin(a) * r * 0.8 - 2, 4, 4); } c.globalAlpha = 1; }
    if (f.k === 'zap') { const x1 = f.sky ? sx(f.x2) : sx(f.x), y1 = f.sky ? sy(f.y2, 9) : sy(f.y, 0.5), x2 = sx(f.x2), y2 = sy(f.y2, 0.5); c.strokeStyle = 'rgba(190,230,255,' + (1 - k) + ')'; c.lineWidth = 3; c.beginPath(); c.moveTo(x1, y1); c.lineTo((x1 + x2) / 2 + (rnd() - 0.5) * CELL * 0.6, (y1 + y2) / 2 + (rnd() - 0.5) * CELL * 0.4); c.lineTo(x2, y2); c.stroke(); }
  }
  const near = G.phase === 'day' && !G.pull && G.hilts.find(h => !h.gone && Math.hypot(h.x - G.x, h.y - G.y) < 1.1);
  c.textAlign = 'center';
  if (near) { c.fillStyle = '#fff'; c.font = '600 13px system-ui'; c.fillText(G.free > 0 ? 'E 뽑기 (공짜)' : 'E 뽑기 · 체력 ' + pullCost(), sx(near.x), sy(near.y, 1.05)); }
  for (const n of G.nums) { c.globalAlpha = 1 - n.a / 0.8; c.fillStyle = n.c; c.font = (n.big ? '700 20px' : '600 14px') + ' system-ui'; c.fillText(n.t, sx(n.x), sy(n.y, n.h) - n.a * 40); } c.globalAlpha = 1;
  c.restore();
  if (night) { const X = sx(G.x), Y = sy(G.y, 0.5), g = c.createRadialGradient(X, Y, CELL * 2, X, Y, Math.max(W, Hh) * 0.75); g.addColorStop(0, 'rgba(6,8,22,.12)'); g.addColorStop(1, 'rgba(4,5,16,.78)'); c.fillStyle = g; c.fillRect(0, 0, W, Hh); }
  if (G.stopT > 0) { c.fillStyle = 'rgba(120,170,255,.12)'; c.fillRect(0, 0, W, Hh); }
  if (G.pull) { const p = G.pull, w = 160, X = W / 2 - w / 2, Y = Hh * 0.72; c.fillStyle = 'rgba(0,0,0,.6)'; c.fillRect(X, Y, w, 8); c.fillStyle = '#e7dcc6'; c.fillRect(X, Y, w * Math.min(1, (p.t % 0.42) / 0.42), 8); }
  if (G.flash) { c.globalAlpha = Math.max(0, G.flash.a); c.fillStyle = G.flash.c; c.fillRect(0, 0, W, Hh); c.globalAlpha = 1; }
}
const desc = (s, k) => { const d = INS[k], v = s.ins[k]; return '<span class="in"><b>' + k + '</b> ' + d[0].replace('N', v) + (s.extra === k ? ' (어머니)' : '') + '</span>'; };
function card(s, k, act) {
  if (!s) return '<div class="sc empty' + (act ? ' act' : '') + '"><kbd>' + (k + 1) + '</kbd><span class="nm">' + (act ? '맨손' : '빈 칸') + '</span><span class="sub">낮에 검을 뽑아 채워</span></div>';
  const st = FM[s.f], dmg = Math.round(LORD.dmg * st[0] * DM[s.g]);
  return '<div class="sc' + (act ? ' act' : '') + '" style="color:' + GC[s.g] + '"><i></i><kbd>' + (k + 1) + '</kbd><span class="nm">' + s.n + '</span><span class="sub">' + GN[s.g] + ' ' + FN[s.f] + ' · 피해 ' + dmg + ' · 내구 ' + (isFinite(s.max) ? Math.ceil(s.dur) + '/' + s.max : '∞') + '</span>' +
    '<span class="db"><em style="width:' + (isFinite(s.max) ? 100 * s.dur / s.max : 100) + '%"></em></span>' + Object.keys(s.ins).map(x => desc(s, x)).join('') + (s.u ? '<span class="in uq">' + s.u + (TODO.has(s.n) ? ' <u>(시험판에서는 아직 작동 안 함)</u>' : '') + '</span>' : '') + '</div>';
}
function drawCards() { $('cards').innerHTML = card(G.sw[0], 0, G.act === 0) + card(G.sw[1], 1, G.act === 1); }
function drawChoice() {
  $('td').classList.add('ch'); const s = G.choice; $('chX').innerHTML = '두고 간다<kbd>X</kbd>'; $('chX').classList.remove('warn');
  $('chNew').innerHTML = card(s, -1, true).replace('<kbd>0</kbd>', ''); $('chA').innerHTML = card(G.sw[0], 0, false); $('chB').innerHTML = card(G.sw[1], 1, false);
}
let hudT = 0;
function hud() {
  const night = G.phase === 'night', last = G.zone === ZONES - 1;
  $('td').classList.toggle('night', night);
  $('hDay').textContent = (G.zone + 1) + '구역 ' + ZN[G.zone] + ' · ' + (night ? '밤' : '낮');
  $('hBarI').style.width = (night ? 100 * (1 - Math.max(0, G.tN) / T_NIGHT) : 0) + '%';
  $('hSub').textContent = night ? (G.tN > 0 ? '새벽까지 ' + Math.ceil(G.tN) + '초' : '언덕지기를 쓰러뜨려') + ' · 적 ' + G.en.length : '남은 검 ' + G.hilts.filter(h => !h.gone).length + ' · 뽑기 운 ×' + (Math.round(luck() * 100) / 100) + (G.free ? ' · 공짜 뽑기 ' + G.free : '');
  $('hpT').textContent = Math.max(0, Math.ceil(G.hp)) + ' / ' + HP + (G.shield > 0 ? ' (+' + Math.round(G.shield) + ')' : ''); $('hpI').style.width = Math.max(0, 100 * G.hp / HP) + '%';
  $('bNight').style.display = night ? 'none' : '';
  for (let k = 0; k < 2; k++) { const s = G.sw[k], el = $('cards').children[k]; if (!el) continue; el.classList.toggle('act', G.act === k); if (s && isFinite(s.max)) { const sub = el.querySelector('.sub'); sub.textContent = sub.textContent.replace(/내구 .*/, '내구 ' + Math.ceil(s.dur) + '/' + s.max); el.querySelector('.db em').style.width = 100 * s.dur / s.max + '%'; } }
  if (sayT > 0 && (sayT -= 0.1) <= 0) $('toast').classList.remove('on');
}
function dex() {
  const el = $('dexBody'); let h = '<p class="none">찾은 검 ' + SW.filter(s => owned[s[0]]).length + ' / ' + SW.length + '</p>';
  GN.forEach((n, g) => { const l = BYG[g]; h += '<h3 style="color:' + GC[g] + '">' + n + ' <small>' + l.filter(i => owned[SW[i][0]]).length + ' / ' + l.length + ' · 1/' + ODDS[g].toLocaleString() + '</small></h3><div class="dl">' + l.map(i => owned[SW[i][0]] ? '<span title="' + (SW[i][4] || '') + '">' + SW[i][0] + ' <small>' + FN[SW[i][2]] + (owned[SW[i][0]] > 1 ? ' ×' + owned[SW[i][0]] : '') + '</small></span>' : '<span class="q">???</span>').join('') + '</div>'; });
  el.innerHTML = h; $('td').classList.add('dx');
}

// ===================== [입력] =====================
const keys = new Set(), mouse = { x: 0, y: 0, down: false, on: false }; let want = { atk: false, dash: false }, touch = false; const joy = { on: false, x: 0, y: 0, id: -1 };
const active = () => !S && !$('td').classList.contains('dx');
addEventListener('keydown', e => {
  if (!active()) { if (e.code === 'Escape') $('td').classList.remove('dx'); return; }
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT') return;
  keys.add(e.code); mouse.on = mouse.on && e.code !== 'KeyJ';
  if (G.choice) { if (e.code === 'Digit1') choose(0); if (e.code === 'Digit2') choose(1); if (e.code === 'KeyX' || e.code === 'Escape') choose(-1); return; }
  if (e.code === 'KeyE') tryPull(); if (e.code === 'KeyN') startNight(); if (e.code === 'KeyQ' || e.code === 'Tab') { swap(); e.preventDefault(); }
  if (e.code === 'Digit1' && G.sw[0] && G.act !== 0) swap(); if (e.code === 'Digit2' && G.sw[1] && G.act !== 1) swap();
  if (e.code === 'Space' || e.code === 'KeyJ') { want.atk = true; e.preventDefault(); } if (e.code === 'ShiftLeft' || e.code === 'ShiftRight' || e.code === 'KeyK') want.dash = true;
  if (e.code === 'KeyB') dex(); if (e.code === 'Backquote' || e.code === 'F2') $('td').classList.toggle('adm');
});
addEventListener('keyup', e => keys.delete(e.code));
cv.addEventListener('mousemove', e => { mouse.x = e.clientX; mouse.y = e.clientY; mouse.on = true; });
cv.addEventListener('mousedown', e => { if (touch) return; mouse.down = true; mouse.on = true; mouse.x = e.clientX; mouse.y = e.clientY; want.atk = true; });
addEventListener('mouseup', () => mouse.down = false);
addEventListener('touchstart', () => { if (!touch) { touch = true; $('td').classList.add('touch'); layout(); } }, { passive: true });
const jEl = $('joy'), jK = $('joyK');
const jMove = t => { const r = jEl.getBoundingClientRect(), dx = t.clientX - r.left - r.width / 2, dy = t.clientY - r.top - r.height / 2, m = Math.hypot(dx, dy), k = Math.min(1, m / (r.width / 2)) / (m || 1); joy.x = dx * k; joy.y = dy * k; jK.style.transform = 'translate(' + joy.x * 40 + 'px,' + joy.y * 40 + 'px)'; };
jEl.addEventListener('touchstart', e => { const t = e.changedTouches[0]; joy.on = true; joy.id = t.identifier; jMove(t); e.preventDefault(); }, { passive: false });
jEl.addEventListener('touchmove', e => { for (const t of e.changedTouches) if (t.identifier === joy.id) jMove(t); e.preventDefault(); }, { passive: false });
const jEnd = e => { for (const t of e.changedTouches) if (t.identifier === joy.id) { joy.on = false; joy.x = joy.y = 0; jK.style.transform = ''; } };
jEl.addEventListener('touchend', jEnd); jEl.addEventListener('touchcancel', jEnd);
let tAtk = false;
const hold = (id, dn, up) => { const el = $(id); el.addEventListener('touchstart', e => { dn(); e.preventDefault(); }, { passive: false }); el.addEventListener('touchend', e => { up && up(); e.preventDefault(); }, { passive: false }); el.addEventListener('mousedown', dn); };
hold('tA', () => { tAtk = true; want.atk = true; }, () => tAtk = false); hold('tD', () => want.dash = true); hold('tE', () => tryPull()); hold('tQ', () => swap());
function readInput() {
  let x = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0) + joy.x, y = (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0) - (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) + joy.y;
  const inp = { x, y, atk: want.atk || mouse.down || tAtk || keys.has('Space') || keys.has('KeyJ'), dash: want.dash };
  if (mouse.on && !touch) inp.aim = { x: (mouse.x - W / 2) / CELL + cam.x, y: (mouse.y - CY + 0.45 * CELL) / (CELL * K) + cam.y };   // 커서를 몸통 높이로 본다
  else if (inp.atk) { let b = null, bd = 6; for (const e of G.en) { const d = Math.hypot(e.x - G.x, e.y - G.y) - e.D.r; if (d < bd) { bd = d; b = e; } } if (b) inp.aim = { x: b.x, y: b.y }; }   // 터치·키보드는 가까운 적을 향한다
  want.atk = want.dash = false; return inp;
}
$('bNight').onclick = startNight; $('bDex').onclick = dex; $('bDexX').onclick = () => $('td').classList.remove('dx'); $('bAdm').onclick = () => $('td').classList.toggle('adm');
$('bAgain').onclick = () => { $('td').classList.remove('ov'); newRun(); drawCards(); };
$('chAb').onclick = () => choose(0); $('chBb').onclick = () => choose(1); $('chX').onclick = () => choose(-1);   // 카드 자체는 눌러도 아무 일 없다

// ===================== [관리] =====================
{ const b = $('admBody'), row = () => { const r = document.createElement('div'); r.className = 'arow'; b.appendChild(r); return r; }, btn = (r, t, f) => { const e = document.createElement('button'); e.type = 'button'; e.className = 'btn'; e.textContent = t; e.onclick = f; r.appendChild(e); return e; };
  const h = t => { const e = document.createElement('h3'); e.textContent = t; b.appendChild(e); };
  h('뽑기'); let r = row(); const sel = document.createElement('select'); sel.innerHTML = '<option value="-1">등급 무작위</option>' + GN.map((n, g) => '<option value="' + g + '">다음부터 ' + n + '만</option>').join(''); sel.onchange = () => G.dbg.force = +sel.value; r.appendChild(sel);
  r = row(); const inpN = document.createElement('input'); inpN.placeholder = '검 이름'; inpN.setAttribute('list', 'swl'); const dl = document.createElement('datalist'); dl.id = 'swl'; dl.innerHTML = SW.map(s => '<option value="' + s[0] + '">').join(''); r.appendChild(inpN); r.appendChild(dl);
  btn(r, '이 검 받기', () => { const i = SW.findIndex(s => s[0] === inpN.value.trim()); if (i < 0) return say('관리: 그런 이름의 검이 없어.'); const s = mk(i); G.sw[G.sw[0] && !G.sw[1] ? 1 : G.act] = s; drawCards(); });
  h('영주'); r = row(); btn(r, '체력 채우기', () => G.hp = HP); const gb = btn(r, '무적 끔', () => { G.dbg.god = !G.dbg.god; gb.textContent = '무적 ' + (G.dbg.god ? '켬' : '끔'); }); btn(r, '검 고치기', () => { G.sw.forEach(s => s && (s.dur = s.max)); drawCards(); });
  h('시간'); r = row(); btn(r, '밤 시작', startNight); btn(r, '밤 끝내기', () => { if (G.phase === 'night') { G.en = []; G.tN = 0; G.bossOut = true; } }); btn(r, '다음 구역', () => { if (G.phase === 'day' && G.zone < ZONES - 1) { G.zone++; newDay(); } });
  r = row(); const ts = btn(r, '속도 ×1', () => { G.dbg.ts = G.dbg.ts === 1 ? 2 : G.dbg.ts === 2 ? 0.5 : 1; ts.textContent = '속도 ×' + G.dbg.ts; }); btn(r, '거인 부르기', () => G.phase === 'night' && spawn('giant')); btn(r, '도감 지우기', () => { for (const k in owned) delete owned[k]; save(); });
}

// ===================== [돌리기] =====================
addEventListener('resize', layout);
roll = () => {}; reward = () => {};
document.body.classList.add('td');
newRun(); layout(); drawCards();
window.HILL = { get G() { return G; }, draw, camStep, layout, SW, mk, update: (dt, inp) => update(dt, inp || { x: 0, y: 0 }), tryPull, startNight, choose: k => { G.choiceAt = 0; if (k < 0) G.discardArm = 1; choose(k); }, attack, spawn, drawCards, newRun, stats, breakSword, GN };
let prev = performance.now();
(function loop(now) {
  const real = Math.min(0.05, (now - prev) / 1000); prev = now;
  document.body.classList.toggle('rev', !!S);
  if (!S && G.pend) { const s = G.pend; G.pend = null; got(s); }
  if (active()) {
    try {
      if (G.flash && (G.flash.a -= real * 1.5) <= 0) G.flash = null;
      G.shake = Math.max(0, G.shake - real * 2.5);
      if (G.hitstop > 0) G.hitstop -= real; else update(real * G.dbg.ts, readInput());
      camStep(real); draw(); if ((hudT += real) > 0.1) { hudT = 0; hud(); }
    } catch (e) { console.error(e); }
  }
  requestAnimationFrame(loop);
})(prev);
}
