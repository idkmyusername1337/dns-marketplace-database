-- ============================================================
--  MARKETPLACE URL WHITELIST DATABASE
--  PostgreSQL schema + seed data
--  Covers: e-commerce, B2B, digital goods, classifieds,
--          travel, food delivery, ride-hailing, and more
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- fuzzy URL matching

-- ------------------------------------------------------------
-- 1. CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_category (
    id          SERIAL PRIMARY KEY,
    slug        VARCHAR(64)  NOT NULL UNIQUE,
    label       VARCHAR(128) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO marketplace_category (slug, label, description) VALUES
  ('ecommerce',        'General E-Commerce',     'Multi-category retail marketplaces'),
  ('fashion',          'Fashion & Apparel',       'Clothing, footwear, accessories'),
  ('electronics',      'Electronics & Tech',      'Gadgets, computers, software'),
  ('digital_goods',    'Digital Goods',           'Software, games, media, subscriptions'),
  ('handmade',         'Handmade & Crafts',       'Artisan and independent creator goods'),
  ('b2b',              'B2B / Wholesale',         'Business-to-business procurement platforms'),
  ('classifieds',      'Classifieds & Auctions',  'Peer-to-peer listings and auctions'),
  ('travel',           'Travel & Accommodation',  'Flights, hotels, holiday rentals'),
  ('food_delivery',    'Food & Grocery Delivery', 'Restaurant and grocery ordering'),
  ('ride_hailing',     'Ride-hailing & Mobility', 'Taxi, e-scooter, bike-share'),
  ('freelance',        'Freelance & Services',    'Gig economy and professional services'),
  ('real_estate',      'Real Estate',             'Property sales and rentals'),
  ('automotive',       'Automotive',              'Car sales, parts, leasing'),
  ('books_education',  'Books & Education',       'Textbooks, courses, learning platforms'),
  ('health_beauty',    'Health & Beauty',         'Pharmacy, personal care, cosmetics'),
  ('financial',        'Financial Services',      'Banking, insurance, payments'),
  ('crypto',           'Crypto / Web3',           'NFT, DEX, token launchpads');

-- ------------------------------------------------------------
-- 2. MARKETPLACES  (parent entity)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(128) NOT NULL,
    category_id     INT          NOT NULL REFERENCES marketplace_category(id),
    hq_country      CHAR(2),                        -- ISO 3166-1 alpha-2
    founded_year    SMALLINT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 3. WHITELISTED URLS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS marketplace_url (
    id              BIGSERIAL    PRIMARY KEY,
    marketplace_id  INT          NOT NULL REFERENCES marketplace(id) ON DELETE CASCADE,
    url             TEXT         NOT NULL,
    url_type        VARCHAR(32)  NOT NULL DEFAULT 'root'
                    CHECK (url_type IN ('root','subdomain','app','api','cdn','help','mobile')),
    protocol        VARCHAR(8)   NOT NULL DEFAULT 'https'
                    CHECK (protocol IN ('https','http','wss')),
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_verified     BOOLEAN      NOT NULL DEFAULT TRUE,
    verified_at     TIMESTAMPTZ,
    notes           TEXT,
    added_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (url)
);

-- GIN index for fast substring/prefix search on URLs
CREATE INDEX IF NOT EXISTS idx_marketplace_url_trgm
    ON marketplace_url USING gin (url gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_marketplace_url_type
    ON marketplace_url (url_type);

CREATE INDEX IF NOT EXISTS idx_marketplace_url_verified
    ON marketplace_url (is_verified);

-- ------------------------------------------------------------
-- 4. TRUST SIGNALS  (third-party verifications, trust seals)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trust_signal (
    id              SERIAL PRIMARY KEY,
    marketplace_id  INT     NOT NULL REFERENCES marketplace(id) ON DELETE CASCADE,
    signal_type     VARCHAR(64),   -- e.g. 'ssl_ev', 'pci_dss', 'iso27001', 'bbb_accredited'
    issuer          VARCHAR(128),
    valid_until     DATE,
    source_url      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 5. REDIRECT / ALIAS  (known legitimate redirects)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS url_alias (
    id              BIGSERIAL PRIMARY KEY,
    alias_url       TEXT NOT NULL UNIQUE,
    canonical_url_id BIGINT NOT NULL REFERENCES marketplace_url(id) ON DELETE CASCADE,
    alias_type      VARCHAR(32) DEFAULT 'redirect'
                    CHECK (alias_type IN ('redirect','short_link','regional','deprecated')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 6. AUDIT LOG
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS whitelist_audit_log (
    id          BIGSERIAL   PRIMARY KEY,
    action      VARCHAR(16) NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE','VERIFY','FLAG')),
    table_name  VARCHAR(64),
    record_id   BIGINT,
    changed_by  VARCHAR(128),
    note        TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger to keep updated_at current on marketplace
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS set_updated_at ON marketplace;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON marketplace
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- ============================================================
--  SEED DATA — Marketplaces
-- ============================================================

-- ---- General E-Commerce ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Amazon',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'US', 1994),
  ('eBay',         (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'US', 1995),
  ('Walmart',      (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'US', 1962),
  ('Target',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'US', 1902),
  ('AliExpress',   (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'CN', 2010),
  ('Taobao',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'CN', 2003),
  ('Tmall',        (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'CN', 2008),
  ('JD.com',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'CN', 1998),
  ('Flipkart',     (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'IN', 2007),
  ('Meesho',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'IN', 2015),
  ('Shopee',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'SG', 2015),
  ('Lazada',       (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'SG', 2012),
  ('Rakuten',      (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'JP', 1997),
  ('Mercado Libre',(SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'AR', 1999),
  ('Temu',         (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'CN', 2022),
  ('Wish',         (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'US', 2010),
  ('Jumia',        (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'NG', 2012),
  ('Noon',         (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'AE', 2017),
  ('Allegro',      (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'PL', 1999),
  ('Otto',         (SELECT id FROM marketplace_category WHERE slug='ecommerce'), 'DE', 1949);

-- ---- Fashion ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('ASOS',         (SELECT id FROM marketplace_category WHERE slug='fashion'), 'GB', 2000),
  ('Zalando',      (SELECT id FROM marketplace_category WHERE slug='fashion'), 'DE', 2008),
  ('Zara',         (SELECT id FROM marketplace_category WHERE slug='fashion'), 'ES', 1974),
  ('H&M',          (SELECT id FROM marketplace_category WHERE slug='fashion'), 'SE', 1947),
  ('Shein',        (SELECT id FROM marketplace_category WHERE slug='fashion'), 'CN', 2008),
  ('Depop',        (SELECT id FROM marketplace_category WHERE slug='fashion'), 'GB', 2011),
  ('Vinted',       (SELECT id FROM marketplace_category WHERE slug='fashion'), 'LT', 2008),
  ('Poshmark',     (SELECT id FROM marketplace_category WHERE slug='fashion'), 'US', 2011),
  ('The RealReal', (SELECT id FROM marketplace_category WHERE slug='fashion'), 'US', 2011),
  ('Vestiaire Collective',(SELECT id FROM marketplace_category WHERE slug='fashion'),'FR',2009),
  ('Myntra',       (SELECT id FROM marketplace_category WHERE slug='fashion'), 'IN', 2007),
  ('Nykaa Fashion',(SELECT id FROM marketplace_category WHERE slug='fashion'), 'IN', 2012),
  ('SSENSE',       (SELECT id FROM marketplace_category WHERE slug='fashion'), 'CA', 2000),
  ('Farfetch',     (SELECT id FROM marketplace_category WHERE slug='fashion'), 'GB', 2007),
  ('Net-a-Porter', (SELECT id FROM marketplace_category WHERE slug='fashion'), 'GB', 2000);

-- ---- Electronics ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Newegg',          (SELECT id FROM marketplace_category WHERE slug='electronics'), 'US', 2001),
  ('Best Buy',        (SELECT id FROM marketplace_category WHERE slug='electronics'), 'US', 1966),
  ('B&H Photo',       (SELECT id FROM marketplace_category WHERE slug='electronics'), 'US', 1973),
  ('Adorama',         (SELECT id FROM marketplace_category WHERE slug='electronics'), 'US', 1975),
  ('MediaMarkt',      (SELECT id FROM marketplace_category WHERE slug='electronics'), 'DE', 1979),
  ('Currys',          (SELECT id FROM marketplace_category WHERE slug='electronics'), 'GB', 1884),
  ('Croma',           (SELECT id FROM marketplace_category WHERE slug='electronics'), 'IN', 2006),
  ('Vijay Sales',     (SELECT id FROM marketplace_category WHERE slug='electronics'), 'IN', 1967),
  ('Cdiscount',       (SELECT id FROM marketplace_category WHERE slug='electronics'), 'FR', 1998);

-- ---- Digital Goods ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Steam',        (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2003),
  ('Epic Games Store',(SELECT id FROM marketplace_category WHERE slug='digital_goods'),'US',2018),
  ('GOG.com',      (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'PL', 2008),
  ('Humble Bundle',(SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2010),
  ('Fanatical',    (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'GB', 2012),
  ('Green Man Gaming',(SELECT id FROM marketplace_category WHERE slug='digital_goods'),'GB',2009),
  ('Bandcamp',     (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2007),
  ('Gumroad',      (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2011),
  ('Itch.io',      (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2013),
  ('Envato Market',(SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'AU', 2006),
  ('Creative Market',(SELECT id FROM marketplace_category WHERE slug='digital_goods'),'US',2012),
  ('AppSumo',      (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2010),
  ('StackSocial',  (SELECT id FROM marketplace_category WHERE slug='digital_goods'), 'US', 2011);

-- ---- Handmade ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Etsy',         (SELECT id FROM marketplace_category WHERE slug='handmade'), 'US', 2005),
  ('Artfire',      (SELECT id FROM marketplace_category WHERE slug='handmade'), 'US', 2008),
  ('Folksy',       (SELECT id FROM marketplace_category WHERE slug='handmade'), 'GB', 2008),
  ('Zibbet',       (SELECT id FROM marketplace_category WHERE slug='handmade'), 'AU', 2009),
  ('Storenvy',     (SELECT id FROM marketplace_category WHERE slug='handmade'), 'US', 2010),
  ('DaWanda',      (SELECT id FROM marketplace_category WHERE slug='handmade'), 'DE', 2006);

-- ---- B2B / Wholesale ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Alibaba.com',  (SELECT id FROM marketplace_category WHERE slug='b2b'), 'CN', 1999),
  ('Global Sources',(SELECT id FROM marketplace_category WHERE slug='b2b'),'HK', 1971),
  ('Made-in-China',(SELECT id FROM marketplace_category WHERE slug='b2b'), 'CN', 1998),
  ('IndiaMART',    (SELECT id FROM marketplace_category WHERE slug='b2b'), 'IN', 1999),
  ('TradeIndia',   (SELECT id FROM marketplace_category WHERE slug='b2b'), 'IN', 2000),
  ('ThomasNet',    (SELECT id FROM marketplace_category WHERE slug='b2b'), 'US', 1898),
  ('Faire',        (SELECT id FROM marketplace_category WHERE slug='b2b'), 'US', 2017),
  ('Angi (Angie''s List)',(SELECT id FROM marketplace_category WHERE slug='b2b'),'US',1995),
  ('Tundra',       (SELECT id FROM marketplace_category WHERE slug='b2b'), 'US', 2017);

-- ---- Classifieds / Auctions ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Craigslist',   (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'US', 1995),
  ('Gumtree',      (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'GB', 2000),
  ('OLX',          (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'NL', 2006),
  ('Quikr',        (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'IN', 2008),
  ('Facebook Marketplace',(SELECT id FROM marketplace_category WHERE slug='classifieds'),'US',2016),
  ('Nextdoor',     (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'US', 2011),
  ('Wallapop',     (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'ES', 2013),
  ('Leboncoin',    (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'FR', 2006),
  ('Kleinanzeigen',(SELECT id FROM marketplace_category WHERE slug='classifieds'), 'DE', 2009),
  ('Marktplaats',  (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'NL', 1999),
  ('Catawiki',     (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'NL', 2008),
  ('Invaluable',   (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'US', 1989),
  ('Bonanza',      (SELECT id FROM marketplace_category WHERE slug='classifieds'), 'US', 2007);

-- ---- Travel ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Booking.com',  (SELECT id FROM marketplace_category WHERE slug='travel'), 'NL', 1996),
  ('Airbnb',       (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 2008),
  ('Expedia',      (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 1996),
  ('Vrbo',         (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 1995),
  ('TripAdvisor',  (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 2000),
  ('Kayak',        (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 2004),
  ('Skyscanner',   (SELECT id FROM marketplace_category WHERE slug='travel'), 'GB', 2003),
  ('Hotels.com',   (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 1991),
  ('Trivago',      (SELECT id FROM marketplace_category WHERE slug='travel'), 'DE', 2005),
  ('GetYourGuide', (SELECT id FROM marketplace_category WHERE slug='travel'), 'DE', 2009),
  ('Viator',       (SELECT id FROM marketplace_category WHERE slug='travel'), 'US', 1999),
  ('Hostelworld',  (SELECT id FROM marketplace_category WHERE slug='travel'), 'IE', 1999),
  ('MakeMyTrip',   (SELECT id FROM marketplace_category WHERE slug='travel'), 'IN', 2000),
  ('Cleartrip',    (SELECT id FROM marketplace_category WHERE slug='travel'), 'IN', 2006),
  ('Yatra',        (SELECT id FROM marketplace_category WHERE slug='travel'), 'IN', 2006);

-- ---- Food Delivery ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('DoorDash',     (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'US', 2013),
  ('Uber Eats',    (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'US', 2014),
  ('Grubhub',      (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'US', 2004),
  ('Instacart',    (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'US', 2012),
  ('Deliveroo',    (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'GB', 2013),
  ('Just Eat',     (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'GB', 2001),
  ('Takeaway.com', (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'NL', 2000),
  ('Zomato',       (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'IN', 2008),
  ('Swiggy',       (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'IN', 2014),
  ('Rappi',        (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'CO', 2015),
  ('iFood',        (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'BR', 2011),
  ('Meituan',      (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'CN', 2010),
  ('Talabat',      (SELECT id FROM marketplace_category WHERE slug='food_delivery'), 'KW', 2004);

-- ---- Ride-Hailing ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Uber',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'US', 2009),
  ('Lyft',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'US', 2012),
  ('Ola',          (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'IN', 2010),
  ('Grab',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'SG', 2012),
  ('DiDi',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'CN', 2012),
  ('Bolt',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'EE', 2013),
  ('Yandex Taxi',  (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'RU', 2011),
  ('inDriver',     (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'RU', 2012),
  ('Gett',         (SELECT id FROM marketplace_category WHERE slug='ride_hailing'), 'IL', 2010);

-- ---- Freelance / Services ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Fiverr',       (SELECT id FROM marketplace_category WHERE slug='freelance'), 'IL', 2010),
  ('Upwork',       (SELECT id FROM marketplace_category WHERE slug='freelance'), 'US', 1998),
  ('Toptal',       (SELECT id FROM marketplace_category WHERE slug='freelance'), 'US', 2010),
  ('Freelancer.com',(SELECT id FROM marketplace_category WHERE slug='freelance'),'AU', 2009),
  ('PeoplePerHour',(SELECT id FROM marketplace_category WHERE slug='freelance'), 'GB', 2007),
  ('Guru.com',     (SELECT id FROM marketplace_category WHERE slug='freelance'), 'US', 1998),
  ('99designs',    (SELECT id FROM marketplace_category WHERE slug='freelance'), 'AU', 2008),
  ('TaskRabbit',   (SELECT id FROM marketplace_category WHERE slug='freelance'), 'US', 2008),
  ('Bark.com',     (SELECT id FROM marketplace_category WHERE slug='freelance'), 'GB', 2014),
  ('Workana',      (SELECT id FROM marketplace_category WHERE slug='freelance'), 'AR', 2012),
  ('Urban Company',(SELECT id FROM marketplace_category WHERE slug='freelance'), 'IN', 2014);

-- ---- Real Estate ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Zillow',       (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'US', 2006),
  ('Realtor.com',  (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'US', 1996),
  ('Redfin',       (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'US', 2004),
  ('Rightmove',    (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'GB', 2000),
  ('Zoopla',       (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'GB', 2008),
  ('Immobilienscout24',(SELECT id FROM marketplace_category WHERE slug='real_estate'),'DE',1998),
  ('MagicBricks',  (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'IN', 2006),
  ('99acres',      (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'IN', 2005),
  ('Housing.com',  (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'IN', 2012),
  ('SeLoger',      (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'FR', 1992),
  ('Domain',       (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'AU', 2004),
  ('REA Group',    (SELECT id FROM marketplace_category WHERE slug='real_estate'), 'AU', 1995);

-- ---- Automotive ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('AutoTrader',   (SELECT id FROM marketplace_category WHERE slug='automotive'), 'US', 1997),
  ('Cars.com',     (SELECT id FROM marketplace_category WHERE slug='automotive'), 'US', 1998),
  ('CarGurus',     (SELECT id FROM marketplace_category WHERE slug='automotive'), 'US', 2006),
  ('Carvana',      (SELECT id FROM marketplace_category WHERE slug='automotive'), 'US', 2012),
  ('Vroom',        (SELECT id FROM marketplace_category WHERE slug='automotive'), 'US', 2013),
  ('AutoScout24',  (SELECT id FROM marketplace_category WHERE slug='automotive'), 'DE', 1998),
  ('mobile.de',    (SELECT id FROM marketplace_category WHERE slug='automotive'), 'DE', 1996),
  ('CarDekho',     (SELECT id FROM marketplace_category WHERE slug='automotive'), 'IN', 2008),
  ('CarWale',      (SELECT id FROM marketplace_category WHERE slug='automotive'), 'IN', 2005),
  ('BikeDekho',    (SELECT id FROM marketplace_category WHERE slug='automotive'), 'IN', 2009),
  ('Cazoo',        (SELECT id FROM marketplace_category WHERE slug='automotive'), 'GB', 2018),
  ('AA Cars',      (SELECT id FROM marketplace_category WHERE slug='automotive'), 'GB', 2014),
  ('Carsales',     (SELECT id FROM marketplace_category WHERE slug='automotive'), 'AU', 1997);

-- ---- Books & Education ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('Coursera',     (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2012),
  ('Udemy',        (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2010),
  ('edX',          (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2012),
  ('Skillshare',   (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2010),
  ('Chegg',        (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2005),
  ('ThriftBooks',  (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2003),
  ('AbeBooks',     (SELECT id FROM marketplace_category WHERE slug='books_education'), 'CA', 1996),
  ('Book Depository',(SELECT id FROM marketplace_category WHERE slug='books_education'),'GB',2004),
  ('Audible',      (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 1995),
  ('Scribd',       (SELECT id FROM marketplace_category WHERE slug='books_education'), 'US', 2007),
  ('Byjus',        (SELECT id FROM marketplace_category WHERE slug='books_education'), 'IN', 2011),
  ('Unacademy',    (SELECT id FROM marketplace_category WHERE slug='books_education'), 'IN', 2010);

-- ---- Health & Beauty ----
INSERT INTO marketplace (name, category_id, hq_country, founded_year) VALUES
  ('iHerb',        (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'US', 1996),
  ('Vitacost',     (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'US', 1994),
  ('LookFantastic',(SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'GB', 2001),
  ('Nykaa',        (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'IN', 2012),
  ('Chemist Direct',(SELECT id FROM marketplace_category WHERE slug='health_beauty'),'GB',2006),
  ('Netmeds',      (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'IN', 2010),
  ('PharmEasy',    (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'IN', 2015),
  ('Wellness Forever',(SELECT id FROM marketplace_category WHERE slug='health_beauty'),'IN',2008),
  ('Cult.fit',     (SELECT id FROM marketplace_category WHERE slug='health_beauty'), 'IN', 2016);

-- ============================================================
--  SEED DATA — URLs
-- ============================================================

-- Helper: insert URL linked to marketplace by name
-- (used as a convenience pattern in this seed block)

INSERT INTO marketplace_url (marketplace_id, url, url_type, is_primary, verified_at) VALUES
-- Amazon
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.com',  'root',    TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.co.uk','root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.de',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.co.jp','root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.in',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.fr',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.ca',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.com.au','root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.com.br','root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.com.mx','root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.es',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://www.amazon.it',   'root',    FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://m.amazon.com',    'mobile',  FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://smile.amazon.com','subdomain',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Amazon'), 'https://aws.amazon.com',  'subdomain',FALSE,NOW()),

-- eBay
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.com',   'root',   TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.co.uk', 'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.de',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.com.au','root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.in',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.fr',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.it',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.es',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.ca',    'root',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='eBay'), 'https://www.ebay.nl',    'root',   FALSE, NOW()),

-- AliExpress
((SELECT id FROM marketplace WHERE name='AliExpress'), 'https://www.aliexpress.com',  'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='AliExpress'), 'https://www.aliexpress.us',   'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='AliExpress'), 'https://www.aliexpress.ru',   'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='AliExpress'), 'https://m.aliexpress.com',    'mobile',FALSE,NOW()),

-- Flipkart
((SELECT id FROM marketplace WHERE name='Flipkart'), 'https://www.flipkart.com',  'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Flipkart'), 'https://dl.flipkart.com',   'subdomain',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Flipkart'), 'https://m.flipkart.com',    'mobile',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Flipkart'), 'https://seller.flipkart.com','subdomain',FALSE,NOW()),

-- Meesho
((SELECT id FROM marketplace WHERE name='Meesho'), 'https://meesho.com',          'root', TRUE, NOW()),
((SELECT id FROM marketplace WHERE name='Meesho'), 'https://www.meesho.com',       'root', FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Meesho'), 'https://supplier.meesho.com',  'subdomain',FALSE,NOW()),

-- Shopee
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.sg',   'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.com.my','root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.co.id', 'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.co.th', 'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.vn',    'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.ph',    'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Shopee'), 'https://shopee.com.br','root', FALSE, NOW()),

-- Etsy
((SELECT id FROM marketplace WHERE name='Etsy'), 'https://www.etsy.com',       'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Etsy'), 'https://m.etsy.com',         'mobile',   FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Etsy'), 'https://sell.etsy.com',      'subdomain',FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Etsy'), 'https://help.etsy.com',      'help',     FALSE, NOW()),

-- Alibaba.com
((SELECT id FROM marketplace WHERE name='Alibaba.com'), 'https://www.alibaba.com',    'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Alibaba.com'), 'https://seller.alibaba.com', 'subdomain',FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Alibaba.com'), 'https://m.alibaba.com',      'mobile',   FALSE, NOW()),

-- Booking.com
((SELECT id FROM marketplace WHERE name='Booking.com'), 'https://www.booking.com',   'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Booking.com'), 'https://admin.booking.com', 'subdomain',FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Booking.com'), 'https://partner.booking.com','subdomain',FALSE,NOW()),

-- Airbnb
((SELECT id FROM marketplace WHERE name='Airbnb'), 'https://www.airbnb.com',    'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Airbnb'), 'https://www.airbnb.co.uk',  'root',     FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Airbnb'), 'https://www.airbnb.in',     'root',     FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Airbnb'), 'https://www.airbnb.com.au', 'root',     FALSE, NOW()),

-- Steam
((SELECT id FROM marketplace WHERE name='Steam'), 'https://store.steampowered.com','subdomain',TRUE, NOW()),
((SELECT id FROM marketplace WHERE name='Steam'), 'https://steamcommunity.com',    'root',    FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Steam'), 'https://api.steampowered.com',  'api',     FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Steam'), 'https://cdn.cloudflare.steamstatic.com','cdn',FALSE,NOW()),

-- Fiverr
((SELECT id FROM marketplace WHERE name='Fiverr'), 'https://www.fiverr.com',       'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Fiverr'), 'https://sellers.fiverr.com',   'subdomain',FALSE, NOW()),

-- Upwork
((SELECT id FROM marketplace WHERE name='Upwork'), 'https://www.upwork.com',       'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Upwork'), 'https://www.freelancer.com',   'root', FALSE, NOW()),

-- Coursera
((SELECT id FROM marketplace WHERE name='Coursera'), 'https://www.coursera.org',   'root',     TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Coursera'), 'https://www.coursera.org/professional-certificates','root',FALSE,NOW()),

-- Udemy
((SELECT id FROM marketplace WHERE name='Udemy'), 'https://www.udemy.com',        'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Udemy'), 'https://business.udemy.com',   'subdomain',FALSE, NOW()),

-- Zomato
((SELECT id FROM marketplace WHERE name='Zomato'), 'https://www.zomato.com',      'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Zomato'), 'https://www.zomato.com/order','root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Zomato'), 'https://blog.zomato.com',     'subdomain',FALSE,NOW()),

-- Swiggy
((SELECT id FROM marketplace WHERE name='Swiggy'), 'https://www.swiggy.com',      'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Swiggy'), 'https://partner.swiggy.com',  'subdomain',FALSE,NOW()),

-- Walmart
((SELECT id FROM marketplace WHERE name='Walmart'), 'https://www.walmart.com',    'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Walmart'), 'https://www.walmart.com/grocery','root',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Walmart'), 'https://seller.walmart.com', 'subdomain',FALSE,NOW()),

-- Rakuten
((SELECT id FROM marketplace WHERE name='Rakuten'), 'https://www.rakuten.com',    'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Rakuten'), 'https://www.rakuten.co.jp',  'root', FALSE, NOW()),

-- Mercado Libre
((SELECT id FROM marketplace WHERE name='Mercado Libre'),'https://www.mercadolibre.com', 'root', TRUE, NOW()),
((SELECT id FROM marketplace WHERE name='Mercado Libre'),'https://www.mercadopago.com',  'root', FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Mercado Libre'),'https://www.mercadolibre.com.ar','root',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Mercado Libre'),'https://www.mercadolibre.com.br','root',FALSE,NOW()),

-- DoorDash
((SELECT id FROM marketplace WHERE name='DoorDash'), 'https://www.doordash.com',       'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='DoorDash'), 'https://merchant.doordash.com',  'subdomain',FALSE,NOW()),

-- Uber Eats
((SELECT id FROM marketplace WHERE name='Uber Eats'), 'https://www.ubereats.com',      'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Uber Eats'), 'https://restaurants.ubereats.com','subdomain',FALSE,NOW()),

-- Uber
((SELECT id FROM marketplace WHERE name='Uber'), 'https://www.uber.com',             'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Uber'), 'https://driver.uber.com',          'subdomain',FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Uber'), 'https://help.uber.com',            'help', FALSE,NOW()),

-- Ola
((SELECT id FROM marketplace WHERE name='Ola'), 'https://www.olacabs.com',           'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Ola'), 'https://oladriver.app.link',        'app',  FALSE,NOW()),

-- ASOS
((SELECT id FROM marketplace WHERE name='ASOS'), 'https://www.asos.com',             'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='ASOS'), 'https://marketplace.asos.com',     'subdomain',FALSE,NOW()),

-- Zillow
((SELECT id FROM marketplace WHERE name='Zillow'), 'https://www.zillow.com',         'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Zillow'), 'https://www.zillowgroup.com',    'root', FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Zillow'), 'https://hotpads.com',            'root', FALSE,NOW()),

-- AutoTrader
((SELECT id FROM marketplace WHERE name='AutoTrader'), 'https://www.autotrader.com', 'root', TRUE, NOW()),
((SELECT id FROM marketplace WHERE name='AutoTrader'), 'https://www.autotrader.co.uk','root',FALSE,NOW()),

-- Newegg
((SELECT id FROM marketplace WHERE name='Newegg'), 'https://www.newegg.com',         'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Newegg'), 'https://www.newegg.ca',          'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='Newegg'), 'https://www.newegg.com.au',      'root', FALSE, NOW()),

-- iHerb
((SELECT id FROM marketplace WHERE name='iHerb'), 'https://www.iherb.com',           'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='iHerb'), 'https://m.iherb.com',             'mobile',FALSE,NOW()),

-- Nykaa
((SELECT id FROM marketplace WHERE name='Nykaa'), 'https://www.nykaa.com',           'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Nykaa'), 'https://www.nykaaman.com',        'root', FALSE,NOW()),
((SELECT id FROM marketplace WHERE name='Nykaa'), 'https://www.nykaabeauty.com',     'root', FALSE,NOW()),

-- PharmEasy
((SELECT id FROM marketplace WHERE name='PharmEasy'), 'https://pharmeasy.in',        'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='PharmEasy'), 'https://api.pharmeasy.in',    'api',  FALSE, NOW()),

-- IndiaMART
((SELECT id FROM marketplace WHERE name='IndiaMART'), 'https://www.indiamart.com',   'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='IndiaMART'), 'https://seller.indiamart.com','subdomain',FALSE,NOW()),

-- Quikr
((SELECT id FROM marketplace WHERE name='Quikr'), 'https://www.quikr.com',           'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Quikr'), 'https://www.quikrjobs.com',        'root', FALSE,NOW()),

-- MakeMyTrip
((SELECT id FROM marketplace WHERE name='MakeMyTrip'), 'https://www.makemytrip.com', 'root', TRUE, NOW()),
((SELECT id FROM marketplace WHERE name='MakeMyTrip'), 'https://trips.makemytrip.com','subdomain',FALSE,NOW()),

-- Skyscanner
((SELECT id FROM marketplace WHERE name='Skyscanner'), 'https://www.skyscanner.net', 'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Skyscanner'), 'https://www.skyscanner.com', 'root', FALSE, NOW()),

-- Grab
((SELECT id FROM marketplace WHERE name='Grab'), 'https://www.grab.com',             'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Grab'), 'https://driver.grab.com',          'subdomain',FALSE,NOW()),

-- Gumtree
((SELECT id FROM marketplace WHERE name='Gumtree'), 'https://www.gumtree.com',       'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='Gumtree'), 'https://www.gumtree.com.au',    'root', FALSE, NOW()),

-- OLX
((SELECT id FROM marketplace WHERE name='OLX'), 'https://www.olx.com',              'root', TRUE,  NOW()),
((SELECT id FROM marketplace WHERE name='OLX'), 'https://www.olx.in',               'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='OLX'), 'https://www.olx.com.br',           'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='OLX'), 'https://www.olx.pl',               'root', FALSE, NOW()),
((SELECT id FROM marketplace WHERE name='OLX'), 'https://www.olx.pk',               'root', FALSE, NOW());

-- ============================================================
--  USEFUL VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_whitelist_full AS
SELECT
    mu.url,
    mu.url_type,
    mu.protocol,
    mu.is_primary,
    mu.is_verified,
    m.name  AS marketplace_name,
    mc.label AS category,
    m.hq_country,
    m.founded_year,
    mu.added_at
FROM marketplace_url mu
JOIN marketplace m ON m.id = mu.marketplace_id
JOIN marketplace_category mc ON mc.id = m.category_id
WHERE mu.is_verified = TRUE AND m.is_active = TRUE
ORDER BY mc.slug, m.name, mu.is_primary DESC;

-- Quick lookup: is this URL whitelisted?
CREATE OR REPLACE FUNCTION is_url_whitelisted(p_url TEXT)
RETURNS TABLE (
    is_whitelisted BOOLEAN,
    marketplace_name TEXT,
    category TEXT
) LANGUAGE sql STABLE AS $$
    SELECT
        TRUE,
        m.name::TEXT,
        mc.label::TEXT
    FROM marketplace_url mu
    JOIN marketplace m  ON m.id  = mu.marketplace_id
    JOIN marketplace_category mc ON mc.id = m.category_id
    WHERE mu.url = p_url AND mu.is_verified = TRUE AND m.is_active = TRUE
    LIMIT 1;
$$;

-- ============================================================
--  QUICK STATS
-- ============================================================
-- SELECT mc.label, COUNT(mu.id) AS url_count
-- FROM marketplace_url mu
-- JOIN marketplace m ON m.id = mu.marketplace_id
-- JOIN marketplace_category mc ON mc.id = m.category_id
-- GROUP BY mc.label ORDER BY url_count DESC;
