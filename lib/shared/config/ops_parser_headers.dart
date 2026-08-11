import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

const opsParserTokenHeaderName = 'X-Ops-Parser-Token';

void applyOpsParserTokenHeader(HttpClientRequest request) {
  final token = dotenv.maybeGet('OPS_PARSER_API_TOKEN')?.trim() ?? '';
  if (token.isEmpty) return;
  request.headers.set(opsParserTokenHeaderName, token);
}
