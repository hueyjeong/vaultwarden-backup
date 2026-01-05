# Vaultwarden with Quad-Backup & Cloudflare Tunnel

개인용 패스워드 매니저인 [Vaultwarden](https://github.com/dani-garcia/vaultwarden)을 Docker Compose로 구축하고, 데이터 안정성을 위해 **4개의 Google Drive**에 6시간마다 백업하며, **Cloudflare Tunnel**을 통해 안전하게 외부에서 접속할 수 있도록 구성한 프로젝트입니다. 또한 매일 점심(12:00)에 백업 리포트를 이메일로 발송합니다.

## 주요 기능

1.  **Vaultwarden Server**: 공식 Bitwarden 클라이언트와 호환되는 경량 서버.
2.  **Automated Backup**:
    *   **주기**: 6시간마다 실행 (`0 */6 * * *`).
    *   **방식**: 실행 중인 SQLite 데이터베이스를 안전하게 Hot backup 후, 첨부파일과 함께 압축(`zip`)하여 전송.
    *   **대상**: 사용자 설정된 4개의 Rclone Remote (`gdrive1` ~ `gdrive4`).
    *   **관리**: 오래된 백업 파일 자동 정리 설정 가능 (스크립트 내 `RETENTION_DAYS`).
3.  **Cloudflare Tunnel**: 포트 포워딩 없이 안전하게 외부 접속 지원 (HTTPS 자동 적용).
4.  **Daily Report**: 매일 낮 12시에 백업 성공/실패 여부를 집계하여 이메일 발송.

## 설치 및 실행 방법

상세한 설정 방법은 [walkthrough.md](walkthrough.md)를 참고하세요.

### 1. 사전 준비
*   **Rclone Config**: 로컬에서 `gdrive1`, `gdrive2`, `gdrive3`, `gdrive4` 리모트를 설정한 `rclone.conf` 파일.
*   **Cloudflare Tunnel Token**: Cloudflare Zero Trust 대시보드에서 발급받은 토큰.
*   **SMTP 계정**: 백업 리포트 발송을 위한 이메일 계정 정보.

### 2. 설정 파일 작성
프로젝트 루트에 환경 변수 파일과 Rclone 설정 파일을 생성합니다.

1.  `.env` 파일 생성:
    ```bash
    cp env.template .env
    vi .env
    # ADMIN_TOKEN, TUNNEL_TOKEN, SMTP_* 정보 입력
    ```
2.  `rclone.conf` 파일 위치:
    *   프로젝트 루트(`docker-compose.yml`과 같은 위치)에 `rclone.conf` 파일을 복사해 둡니다.

### 3. 실행
```bash
docker-compose up -d --build
```

## 디렉토리 구조
```
.
├── backup/
│   ├── Dockerfile   # 백업 컨테이너 이미지 정의 (Alpine + Rclone + Tools)
│   ├── backup.sh    # 백업 로직 스크립트
│   ├── report.sh    # 이메일 리포팅 스크립트
│   └── crontab      # 스케줄러 설정
├── docker-compose.yml
├── env.template     # 환경 변수 템플릿
├── .env             # (생성 필요) 실제 환경 변수
├── rclone.conf      # (생성 필요) Rclone 설정 파일
└── README.md
```

## 주의 사항
*   **보안**: `.env` 파일과 `rclone.conf` 파일에는 민감한 인증 정보가 포함되어 있으므로 **절대 Git 저장소에 커밋하지 마세요.**
*   **데이터**: Vaultwarden 데이터는 Docker Volume `vw-data`에 영구 저장됩니다.
