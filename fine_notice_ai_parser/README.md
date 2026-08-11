# fine-notice-ai-parser

과태료/주정차/통행료 고지서 사진을 읽어 OPS 과태료 원장 입력 후보를 만드는 보조 파서다.

## Boundary

- `reservation-ai-parser`는 유지한다.
- 이 파서는 `fine-notice-ai-parser` 역할만 가진다.
- 파서 결과는 확정값이 아니다.
- 앱은 `rawCandidate`를 보여주고 사용자가 `confirmedValue`를 입력/수정한다.

## Endpoints

- `GET /health`
- `POST /parse-fine-notice`

## Request

```json
{
  "imageBase64": "...",
  "mimeType": "image/jpeg"
}
```

Fixture/debug:

```json
{
  "fixture": {
    "noticeProfile": "toll_fee.woomyeonsan",
    "noticeType": "toll_fee",
    "rawCandidate": {}
  }
}
```

## Response

```json
{
  "ok": true,
  "noticeProfile": "toll_fee.woomyeonsan",
  "noticeType": "toll_fee",
  "issuer": "우면산인프라웨이(주)",
  "documentNumber": "6419815",
  "rawCandidate": {
    "carNumber": "142호5626",
    "passAt": "2026-05-26 10:00:26",
    "dueDate": "2026-06-22",
    "totalAmount": 2500,
    "items": []
  },
  "confirmedValue": null,
  "fieldCrops": [],
  "warnings": [],
  "confidence": 0.9,
  "meta": {
    "parser": "fine-notice-ai-parser"
  }
}
```

## Commands

```sh
npm --prefix fine_notice_ai_parser run check
npm --prefix fine_notice_ai_parser run simulate
GANGNAM_MULTI_FIXTURE_IMAGE=/local/private/gangnam.jpg npm --prefix fine_notice_ai_parser run gangnam-multi-smoke
```

Real notice photos are local-only smoke inputs and are intentionally ignored by git.
