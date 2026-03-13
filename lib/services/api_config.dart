const String kApiBase = 'https://api-soundbox-backend.onrender.com/api';

const Duration kConnectTimeout = Duration(seconds: 10);
const Duration kReceiveTimeout = Duration(seconds: 15);
const Duration kPingTimeout    = Duration(seconds: 6);

const int kMaxRetries    = 3;
const Duration kRetryDelay = Duration(seconds: 2);
