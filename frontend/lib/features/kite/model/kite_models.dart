/// Kite / Zerodha domain models.
library;

class KiteProfile {
  final String userId;
  final String userName;
  final String userShortname;
  final String email;
  final String userType;
  final String broker;
  final List<String> exchanges;
  final List<String> products;
  final List<String> orderTypes;

  const KiteProfile({
    required this.userId,
    required this.userName,
    required this.userShortname,
    required this.email,
    required this.userType,
    required this.broker,
    required this.exchanges,
    required this.products,
    required this.orderTypes,
  });

  String get name => userName.isNotEmpty
      ? userName
      : (userShortname.isNotEmpty ? userShortname : userId);

  factory KiteProfile.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    // Support both direct and nested `data` wrapper
    final d = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    return KiteProfile(
      userId: (d['user_id'] ?? d['userId'] ?? '') as String,
      userName: (d['user_name'] ?? d['userName'] ?? '') as String,
      userShortname:
          (d['user_shortname'] ?? d['userShortname'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      userType: (d['user_type'] ?? d['userType'] ?? '') as String,
      broker: (d['broker'] ?? '') as String,
      exchanges: toStringList(d['exchanges']),
      products: toStringList(d['products']),
      orderTypes: toStringList(d['order_types'] ?? d['orderTypes']),
    );
  }
}

class KiteLoginUrlResponse {
  final String loginUrl;

  const KiteLoginUrlResponse({required this.loginUrl});

  factory KiteLoginUrlResponse.fromJson(Map<String, dynamic> json) {
    return KiteLoginUrlResponse(
      loginUrl: (json['loginUrl'] ?? json['login_url'] ?? json['url'] ?? '')
          as String,
    );
  }
}

/// Lightweight status tracker — populated from GET /kite/market-data/status.
class KitePortfolioStatus {
  final bool isConnected;
  final String? status;

  const KitePortfolioStatus({required this.isConnected, this.status});

  factory KitePortfolioStatus.fromJson(Map<String, dynamic> json) {
    return KitePortfolioStatus(
      isConnected: (json['connected'] ?? json['isConnected'] ?? false) as bool,
      status: json['status'] as String?,
    );
  }
}

/// Portfolio summary for dashboard strips
class KitePortfolioSummary {
  final double invested;
  final double currentValue;
  final double dayPnl;

  const KitePortfolioSummary({
    required this.invested,
    required this.currentValue,
    required this.dayPnl,
  });

  factory KitePortfolioSummary.fromJson(Map<String, dynamic> json) {
    final holdings = (json['holdings'] as List?) ?? [];
    double invested = 0;
    double current = 0;
    for (final h in holdings) {
      if (h is Map) {
        final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
        final avg =
            (h['average_price'] ?? h['averagePrice'] as num?)?.toDouble() ?? 0;
        final ltp =
            (h['last_price'] ?? h['lastPrice'] as num?)?.toDouble() ?? 0;
        invested += qty * avg;
        current += qty * ltp;
      }
    }

    double dayPnl = 0;
    final dayPositions =
        (json['dayPositions'] as List?) ?? (json['day'] as List?) ?? [];
    for (final p in dayPositions) {
      if (p is Map) {
        dayPnl += (p['pnl'] as num?)?.toDouble() ?? 0;
      }
    }

    return KitePortfolioSummary(
      invested: invested,
      currentValue: current,
      dayPnl: dayPnl,
    );
  }
}

/// Response returned by POST /api/v1/kite/instruments/sync
class InstrumentSyncResponse {
  final int instrumentCount;
  final DateTime? syncedAt;

  const InstrumentSyncResponse({
    required this.instrumentCount,
    this.syncedAt,
  });

  factory InstrumentSyncResponse.fromJson(Map<String, dynamic> json) {
    return InstrumentSyncResponse(
      instrumentCount:
          (json['instrumentCount'] ?? json['instrument_count'] ?? 0) as int,
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'].toString())
          : null,
    );
  }
}

class KiteMargins {
  final double availableCash;
  final double usedMargin;
  final double netMargin;

  const KiteMargins({
    required this.availableCash,
    required this.usedMargin,
    required this.netMargin,
  });

  factory KiteMargins.fromJson(Map<String, dynamic> json) {
    final equity = json['equity'] is Map ? json['equity'] as Map : {};
    final available = equity['available'] is Map ? equity['available'] as Map : {};
    final utilised = equity['utilised'] is Map ? equity['utilised'] as Map : {};

    final cash = (available['cash'] as num?)?.toDouble() ??
        (available['live_balance'] as num?)?.toDouble() ??
        0.0;
    final debits = (utilised['debits'] as num?)?.toDouble() ?? 0.0;
    final net = (equity['net'] as num?)?.toDouble() ?? (cash - debits);

    return KiteMargins(
      availableCash: cash,
      usedMargin: debits,
      netMargin: net,
    );
  }
}
