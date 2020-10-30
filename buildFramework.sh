xcodebuild archive \
  -scheme SSHTunnel \
  -destination="iOS" \
  -destination="macOS" \
  -destination="maccatalyst" \
  SKIP_INSTALL=NO
