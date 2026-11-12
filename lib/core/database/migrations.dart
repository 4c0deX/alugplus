class DatabaseMigrations {
  DatabaseMigrations._();

  static const String databaseName = 'alugplus.db';
  static const int databaseVersion = 2;

  static const String createItemsTable = '''
    CREATE TABLE items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color_hex TEXT NOT NULL,
      photo_path TEXT,
      is_active INTEGER DEFAULT 1
    );
  ''';

  static const String createRentalsTable = '''
    CREATE TABLE rentals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      start_time TEXT NOT NULL,
      planned_end_time TEXT NOT NULL,
      actual_end_time TEXT,
      base_price REAL NOT NULL,
      surcharge REAL DEFAULT 0.0,
      surcharge_applied INTEGER DEFAULT 0,
      is_manual_surcharge INTEGER DEFAULT 0,
      total_paid REAL NOT NULL,
      status TEXT NOT NULL,
      created_date TEXT NOT NULL,
      FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE RESTRICT
    );
  ''';

  static const String createDailyFinancialStatsTable = '''
    CREATE TABLE daily_financial_stats (
      date TEXT PRIMARY KEY,
      total_rentals_count INTEGER DEFAULT 0,
      total_revenue REAL DEFAULT 0.0,
      hourly_data TEXT,
      is_closed INTEGER DEFAULT 0
    );
  ''';

  static const String createIndexes = '''
    CREATE INDEX IF NOT EXISTS idx_rentals_status ON rentals(status);
    CREATE INDEX IF NOT EXISTS idx_rentals_start_time ON rentals(start_time);
    CREATE INDEX IF NOT EXISTS idx_rentals_created_date ON rentals(created_date);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_rentals_unique_active_item ON rentals(item_id) WHERE status = 'active';
  ''';

  /// Trigger complementar de segurança no SQLite para manter no máximo 200 aluguéis 'completed'
  static const String createRetentionTrigger = '''
    CREATE TRIGGER IF NOT EXISTS trg_limit_completed_rentals
    AFTER UPDATE OF status ON rentals
    WHEN NEW.status = 'completed'
    BEGIN
      DELETE FROM rentals
      WHERE id IN (
        SELECT id FROM rentals
        WHERE status = 'completed'
        ORDER BY start_time ASC
        LIMIT MAX(0, (SELECT COUNT(*) FROM rentals WHERE status = 'completed') - 200)
      );
    END;
  ''';

  static const List<Map<String, dynamic>> initialSeedItems = [
    {
      'name': 'Bicicleta Aro 29 Sport #01',
      'type': 'Bicicleta',
      'color_hex': '#1E88E5',
      'photo_path': null,
      'is_active': 1,
    },
    {
      'name': 'Bicicleta Passeio Praiana #02',
      'type': 'Bicicleta',
      'color_hex': '#43A047',
      'photo_path': null,
      'is_active': 1,
    },
    {
      'name': 'Bicicleta Infantil Aro 20 #03',
      'type': 'Bicicleta',
      'color_hex': '#FB8C00',
      'photo_path': null,
      'is_active': 1,
    },
    {
      'name': 'Carrinho Família Duplo #01',
      'type': 'Carrinho',
      'color_hex': '#E53935',
      'photo_path': null,
      'is_active': 1,
    },
    {
      'name': 'Carrinho Pedal Kids #02',
      'type': 'Carrinho',
      'color_hex': '#8E24AA',
      'photo_path': null,
      'is_active': 1,
    },
    {
      'name': 'Patinete Elétrico #01',
      'type': 'Outro',
      'color_hex': '#00ACC1',
      'photo_path': null,
      'is_active': 1,
    },
  ];
}
