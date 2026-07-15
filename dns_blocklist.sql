-- ============================================================
--  DNS BLOCKLIST / AD-DNS DATABASE
--  PostgreSQL schema + extensive seed data
--  Covers: ad networks, tracking, telemetry, malware, phishing,
--          cryptominers, crapware, and adult/NSFW categories
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ------------------------------------------------------------
-- 1. CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dns_category (
    id          SERIAL PRIMARY KEY,
    slug        VARCHAR(64)  NOT NULL UNIQUE,
    label       VARCHAR(128) NOT NULL,
    description TEXT,
    severity    SMALLINT     NOT NULL DEFAULT 2
                CHECK (severity BETWEEN 1 AND 5),   -- 1=low, 5=critical
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO dns_category (slug, label, description, severity) VALUES
  ('ad_network',       'Ad Network',               'Core advertisement serving domains',            2),
  ('tracking',         'Tracking / Analytics',     'User behaviour tracking and analytics beacons',  2),
  ('telemetry',        'Telemetry / Diagnostics',  'OS and app telemetry collection endpoints',      2),
  ('social_tracker',   'Social Media Tracker',     'Third-party social pixels and widgets',          2),
  ('retargeting',      'Retargeting / Remarketing','Retargeting pixels and DSP partners',            2),
  ('data_broker',      'Data Broker',              'Data aggregation and resale services',           3),
  ('malware',          'Malware / Exploit',        'Known malware C2 and exploit kit domains',       5),
  ('phishing',         'Phishing / Fraud',         'Credential-stealing and fraud sites',            5),
  ('cryptominer',      'Cryptominer',              'Browser-based and hidden coin-mining scripts',   4),
  ('ransomware',       'Ransomware C2',            'Ransomware command-and-control servers',         5),
  ('pup',              'PUP / Adware',             'Potentially unwanted programs and bundled adware',3),
  ('pop_under',        'Pop-under / Pop-up',       'Intrusive interstitial and pop ad networks',     2),
  ('affiliate',        'Affiliate / Redirect',     'Affiliate click-tracking redirectors',           1),
  ('click_fraud',      'Click Fraud',              'Fraudulent click-injection and IVT networks',    4),
  ('fingerprinting',   'Browser Fingerprinting',   'Canvas/WebGL fingerprinting scripts',            3),
  ('spyware',          'Spyware / Stalkerware',    'Covert surveillance and location tracking',      5),
  ('adult',            'Adult / NSFW',             'Adult content advertising networks',             2),
  ('fake_news',        'Fake News / Clickbait',    'Outbrain-style clickbait and misinformation',    2),
  ('coin_hive',        'CoinHive Legacy',          'Defunct Coinhive and clones (still seen in wild)',4),
  ('cdn_abuse',        'CDN Abuse',                'Legitimate CDNs abused for malware delivery',    3);

-- ------------------------------------------------------------
-- 2. DNS ENTRY
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dns_entry (
    id              BIGSERIAL    PRIMARY KEY,
    domain          VARCHAR(253) NOT NULL,
    subdomain_block BOOLEAN      NOT NULL DEFAULT TRUE,  -- also block *.domain
    category_id     INT          NOT NULL REFERENCES dns_category(id),
    severity        SMALLINT     NOT NULL DEFAULT 2 CHECK (severity BETWEEN 1 AND 5),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    source          VARCHAR(128),  -- e.g. 'EasyList', 'AdGuard', 'manual'
    first_seen      DATE,
    last_seen       DATE,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (domain)
);

CREATE INDEX IF NOT EXISTS idx_dns_entry_domain_trgm
    ON dns_entry USING gin (domain gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_dns_entry_category
    ON dns_entry (category_id);
CREATE INDEX IF NOT EXISTS idx_dns_entry_active
    ON dns_entry (is_active);
CREATE INDEX IF NOT EXISTS idx_dns_entry_severity
    ON dns_entry (severity);

-- ------------------------------------------------------------
-- 3. IP BLOCKLIST  (known malicious IPs backing domains)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ip_blocklist (
    id          BIGSERIAL PRIMARY KEY,
    ip_cidr     INET         NOT NULL UNIQUE,
    category_id INT          NOT NULL REFERENCES dns_category(id),
    asn         INT,
    asn_org     VARCHAR(256),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    notes       TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 4. ALLOWLIST EXCEPTIONS
--    (e.g. a CDN domain that is mostly safe, or whitelabelled)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dns_exception (
    id              BIGSERIAL    PRIMARY KEY,
    domain          VARCHAR(253) NOT NULL UNIQUE,
    reason          TEXT,
    added_by        VARCHAR(128),
    valid_until     DATE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 5. QUERY LOG  (for DNS resolver integration)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dns_query_log (
    id          BIGSERIAL    PRIMARY KEY,
    queried_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    client_ip   INET,
    domain      VARCHAR(253) NOT NULL,
    was_blocked BOOLEAN      NOT NULL DEFAULT FALSE,
    entry_id    BIGINT       REFERENCES dns_entry(id),
    resolver_ms SMALLINT
);

CREATE INDEX IF NOT EXISTS idx_dns_query_log_domain
    ON dns_query_log (domain);
CREATE INDEX IF NOT EXISTS idx_dns_query_log_blocked
    ON dns_query_log (was_blocked);

-- ------------------------------------------------------------
-- 6. FEED SOURCES  (upstream blocklist feeds)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocklist_feed (
    id              SERIAL       PRIMARY KEY,
    name            VARCHAR(128) NOT NULL UNIQUE,
    url             TEXT,
    format          VARCHAR(32)  DEFAULT 'hosts'
                    CHECK (format IN ('hosts','abp','easylist','dnsmasq','plain','json')),
    last_fetched    TIMESTAMPTZ,
    entry_count     INT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO blocklist_feed (name, url, format, notes) VALUES
  ('EasyList',            'https://easylist.to/easylist/easylist.txt',             'easylist', 'Primary ad filter list'),
  ('EasyPrivacy',         'https://easylist.to/easylist/easyprivacy.txt',          'easylist', 'Tracking filter list'),
  ('AdGuard DNS',         'https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt','abp','AdGuard DNS default'),
  ('AdGuard Base',        'https://filters.adtidy.org/extension/chromium/filters/2.txt','abp','AdGuard base filter'),
  ('Steven Black Hosts',  'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts','hosts','Amalgamated hosts list'),
  ('Dan Pollock Hosts',   'https://someonewhocares.org/hosts/hosts',               'hosts',   'Classic hand-curated list'),
  ('OISD Basic',          'https://dbl.oisd.nl/basic',                             'abp',     'OISD basic blocklist'),
  ('OISD Full',           'https://dbl.oisd.nl',                                   'abp',     'OISD full blocklist'),
  ('Disconnect.me',       'https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt','plain','Disconnect tracking list'),
  ('Peter Lowes Ad List', 'https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts','hosts','Yoyo.org ad servers'),
  ('URLhaus',             'https://urlhaus.abuse.ch/downloads/hostfile',           'hosts',   'Abuse.ch malware URLs'),
  ('Malware Domain List', 'https://www.malwaredomainlist.com/hostslist/hosts.txt', 'hosts',   'MDL classic list'),
  ('Phishtank',           'https://data.phishtank.com/data/online-valid.csv',      'json',    'Verified phishing URLs'),
  ('OpenPhish',           'https://openphish.com/feed.txt',                        'plain',   'OpenPhish community feed'),
  ('NoCoin',              'https://raw.githubusercontent.com/nicehash/NoCoin-adblock-list/master/adblock.txt','abp','Crypto-miner blocklist'),
  ('CoinBlockerLists',    'https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser','hosts','Browser-based miners'),
  ('Goodbye Ads',         'https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Hosts/GoodbyeAds.txt','hosts','Mobile ad blocklist'),
  ('HaGeZi Multi PRO',    'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.txt','hosts','HaGeZi curated list'),
  ('1Hosts Lite',         'https://o0.pages.dev/Lite/hosts.txt',                  'hosts',   '1Hosts lite'),
  ('Spam404',             'https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt','plain','Scam/fraud domains');

-- ============================================================
--  SEED DATA — DNS Entries
-- ============================================================

-- ---- AD NETWORKS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
-- Google Advertising
('doubleclick.net',       (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Google/DoubleClick ad server'),
('googlesyndication.com', (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Google AdSense'),
('googleadservices.com',  (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Google Ads click tracker'),
('googleads.g.doubleclick.net',(SELECT id FROM dns_category WHERE slug='ad_network'),2,'EasyList',   'DFP ad server'),
('pagead2.googlesyndication.com',(SELECT id FROM dns_category WHERE slug='ad_network'),2,'EasyList', 'AdSense script host'),
('adservice.google.com',  (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'AdGuard DNS',   'Google ad service'),
-- Amazon Advertising
('amazon-adsystem.com',   (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Amazon DSP / AAP'),
('adsystem.amazon.com',   (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Amazon ad system'),
('fls-na.amazon.com',     (SELECT id FROM dns_category WHERE slug='tracking'),   2, 'EasyPrivacy',   'Amazon conversion tracking'),
-- Meta / Facebook
('an.facebook.com',       (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Facebook Audience Network'),
('connect.facebook.net',  (SELECT id FROM dns_category WHERE slug='social_tracker'),2,'EasyList',    'Facebook SDK / pixel host'),
('graph.facebook.com',    (SELECT id FROM dns_category WHERE slug='tracking'),   2, 'EasyPrivacy',   'FB Graph API telemetry'),
-- AppNexus / Xandr
('adnxs.com',             (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'AppNexus/Xandr ad exchange'),
('adnxs-simple.com',      (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'AppNexus simple pixel'),
('ib.adnxs.com',          (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'AppNexus impbus'),
-- OpenX
('openx.net',             (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'OpenX ad exchange'),
('ads.openx.net',         (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'OpenX VAST host'),
('d.openx.net',           (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'OpenX delivery'),
-- Rubicon Project / Magnite
('rubiconproject.com',    (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Magnite/Rubicon SSP'),
('fastlane.rubiconproject.com',(SELECT id FROM dns_category WHERE slug='ad_network'),2,'EasyList',   'Rubicon PREBID endpoint'),
-- PubMatic
('pubmatic.com',          (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'PubMatic SSP'),
('ads.pubmatic.com',      (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'PubMatic ad delivery'),
-- SpotX / Magnite CTV
('spotxchange.com',       (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'SpotX video ads'),
('spotx.tv',              (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'SpotX CTV'),
-- Index Exchange
('casalemedia.com',       (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Index Exchange (Casale)'),
('indexww.com',           (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Index Exchange prebid'),
-- Criteo
('criteo.com',            (SELECT id FROM dns_category WHERE slug='retargeting'), 2, 'EasyList',     'Criteo retargeting'),
('rtax.criteo.com',       (SELECT id FROM dns_category WHERE slug='retargeting'), 2, 'EasyList',     'Criteo RTAX bid'),
('dis.criteo.com',        (SELECT id FROM dns_category WHERE slug='retargeting'), 2, 'EasyList',     'Criteo display'),
('static.criteo.net',     (SELECT id FROM dns_category WHERE slug='retargeting'), 2, 'EasyList',     'Criteo script CDN'),
-- The Trade Desk
('adsrvr.org',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'AdGuard DNS',   'The Trade Desk DSP'),
('pixel.adsrvr.org',      (SELECT id FROM dns_category WHERE slug='tracking'),   2, 'AdGuard DNS',   'TTD pixel'),
-- Taboola
('taboola.com',           (SELECT id FROM dns_category WHERE slug='fake_news'),  2, 'EasyList',      'Taboola content recommendation'),
('cdn.taboola.com',       (SELECT id FROM dns_category WHERE slug='fake_news'),  2, 'EasyList',      'Taboola CDN'),
('trc.taboola.com',       (SELECT id FROM dns_category WHERE slug='fake_news'),  2, 'EasyList',      'Taboola recommendation'),
-- Outbrain
('outbrain.com',          (SELECT id FROM dns_category WHERE slug='fake_news'),  2, 'EasyList',      'Outbrain content recommendation'),
('widgets.outbrain.com',  (SELECT id FROM dns_category WHERE slug='fake_news'),  2, 'EasyList',      'Outbrain widget'),
('log.outbrain.com',      (SELECT id FROM dns_category WHERE slug='tracking'),   2, 'EasyPrivacy',   'Outbrain logging'),
-- Conversant / Epsilon
('conversantmedia.com',   (SELECT id FROM dns_category WHERE slug='retargeting'),2, 'EasyList',      'Conversant / Epsilon'),
('dotomi.com',            (SELECT id FROM dns_category WHERE slug='retargeting'),2, 'EasyList',      'Dotomi retargeting'),
-- Undertone
('undertone.com',         (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Undertone high-impact ads'),
-- Yahoo / Oath / Verizon Media
('oath.com',              (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Oath (Verizon Media) ad infra'),
('ads.yahoo.com',         (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Yahoo Gemini Ads'),
('advertising.yahoo.com', (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Yahoo advertising platform'),
('yahoodns.net',          (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Yahoo DSP DNS'),
-- Sovrn / Lijit
('lijit.com',             (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Sovrn/Lijit'),
-- TripleLift
('triplelift.com',        (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'TripleLift native ads'),
-- Sharethrough
('sharethrough.com',      (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Sharethrough native'),
-- Smart AdServer
('smartadserver.com',     (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Smart AdServer'),
('sascdn.com',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Smart AdServer CDN'),
-- EMX Digital
('emxdgt.com',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'EMX Digital exchange'),
-- Smaato
('smaato.net',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Smaato mobile ads'),
-- InMobi
('inmobi.com',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'InMobi mobile DSP'),
-- MoPub (now deprecated / Twitter)
('mopub.com',             (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'MoPub (Twitter/deprecated)'),
-- Verizon Media (formerly Oath/Brightroll)
('brightroll.com',        (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'BrightRoll video DSP'),
-- Yieldmo
('yieldmo.com',           (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Yieldmo format ads'),
-- MediaMath
('mathtag.com',           (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'MediaMath (now Infillion)'),
-- LiveRamp / Acxiom
('liveramp.com',          (SELECT id FROM dns_category WHERE slug='data_broker'), 3, 'manual',       'LiveRamp identity graph'),
('acxiom.com',            (SELECT id FROM dns_category WHERE slug='data_broker'), 3, 'manual',       'Acxiom data broker'),
-- ShareThis
('sharethis.com',         (SELECT id FROM dns_category WHERE slug='tracking'),   3, 'EasyPrivacy',   'ShareThis social tracking'),
-- Zemanta
('zemanta.com',           (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Zemanta (now Outbrain)'),
-- AdRoll
('adroll.com',            (SELECT id FROM dns_category WHERE slug='retargeting'),2, 'EasyList',      'AdRoll retargeting'),
'd.adroll.com',
-- Zeta Global
('zetaglobal.com',        (SELECT id FROM dns_category WHERE slug='data_broker'), 3, 'manual',       'Zeta Global DMP'),
-- Lotame
('crwdcntrl.net',         (SELECT id FROM dns_category WHERE slug='data_broker'), 3, 'EasyPrivacy',  'Lotame DMP'),
-- Exponential / Tribal Fusion
('exponential.com',       (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'EasyList',      'Exponential (Tribal Fusion)'),
-- Yandex Ads
('an.yandex.ru',          (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'AdGuard DNS',   'Yandex Advertising Network'),
('yandex.net',            (SELECT id FROM dns_category WHERE slug='ad_network'), 2, 'AdGuard DNS',   'Yandex ad delivery infra');

-- Remove bad syntax above
DELETE FROM dns_entry WHERE domain = 'd.adroll.com,';

INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('d.adroll.com',          (SELECT id FROM dns_category WHERE slug='retargeting'),2,'EasyList','AdRoll pixel');

-- ---- TRACKING & ANALYTICS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
-- Google Analytics
('google-analytics.com',      (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Google Analytics'),
('ssl.google-analytics.com',  (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','GA SSL endpoint'),
('www.google-analytics.com',  (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','GA main endpoint'),
('analytics.google.com',      (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','GA4'),
-- Tag Manager
('www.googletagmanager.com',  (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Google Tag Manager'),
('googletagservices.com',     (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Google Tag Services'),
-- Segment / Twilio
('segment.com',               (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Segment CDP'),
('api.segment.io',            (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Segment API'),
('cdn.segment.com',           (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Segment CDN'),
-- Amplitude
('amplitude.com',             (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Amplitude analytics'),
('api.amplitude.com',         (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Amplitude API'),
-- Mixpanel
('mixpanel.com',              (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Mixpanel analytics'),
('api.mixpanel.com',          (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Mixpanel API'),
-- Heap
('heapanalytics.com',         (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Heap analytics'),
-- Hotjar
('hotjar.com',                (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Hotjar heatmaps'),
('script.hotjar.com',         (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Hotjar script host'),
('static.hotjar.com',         (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Hotjar static'),
-- FullStory
('fullstory.com',             (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','FullStory session recording'),
('rs.fullstory.com',          (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','FullStory relay'),
-- Mouseflow
('mouseflow.com',             (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Mouseflow session replay'),
-- Clarity
('clarity.ms',                (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Microsoft Clarity'),
-- Quantcast
('quantcast.com',             (SELECT id FROM dns_category WHERE slug='tracking'),3,'EasyPrivacy','Quantcast audience measurement'),
('quantserve.com',            (SELECT id FROM dns_category WHERE slug='tracking'),3,'EasyPrivacy','Quantcast pixel server'),
-- Nielsen
('imrworldwide.com',          (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Nielsen NetRatings'),
-- comScore
('scorecardresearch.com',     (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','comScore ScorecardResearch'),
('beacon.scorecardresearch.com',(SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','comScore beacon'),
-- Adobe Analytics / Omniture
('omtrdc.net',                (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Adobe Analytics (Omniture)'),
('adobedtm.com',              (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Adobe DTM tag manager'),
('demdex.net',                (SELECT id FROM dns_category WHERE slug='tracking'),3,'EasyPrivacy','Adobe Audience Manager'),
-- Chartbeat
('chartbeat.com',             (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Chartbeat real-time analytics'),
('static.chartbeat.com',      (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Chartbeat static'),
-- New Relic (browser agent)
('nr-data.net',               (SELECT id FROM dns_category WHERE slug='telemetry'),2,'EasyPrivacy','New Relic browser agent'),
-- Datadog (browser)
('browser-intake-datadoghq.com',(SELECT id FROM dns_category WHERE slug='telemetry'),2,'manual',  'Datadog browser RUM'),
-- Sentry
('sentry.io',                 (SELECT id FROM dns_category WHERE slug='telemetry'),1,'manual',    'Sentry error tracking (low-privacy risk but sends data)'),
-- LogRocket
('lr-ingest.io',              (SELECT id FROM dns_category WHERE slug='tracking'),2,'manual',    'LogRocket session replay'),
-- Snowplow
('snowplow.io',               (SELECT id FROM dns_category WHERE slug='tracking'),2,'manual',    'Snowplow behavioral data'),
-- mParticle
('mparticle.com',             (SELECT id FROM dns_category WHERE slug='tracking'),2,'manual',    'mParticle CDP'),
-- Tealium
('tiqcdn.com',                (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Tealium iQ tag'),
('collect.tealiumiq.com',     (SELECT id FROM dns_category WHERE slug='tracking'),2,'EasyPrivacy','Tealium event collect'),
-- Klaviyo
('klaviyo.com',               (SELECT id FROM dns_category WHERE slug='tracking'),2,'manual',    'Klaviyo email tracking'),
-- Braze
('braze.com',                 (SELECT id FROM dns_category WHERE slug='tracking'),2,'manual',    'Braze in-app tracking'),
-- OneSignal
('onesignal.com',             (SELECT id FROM dns_category WHERE slug='tracking'),1,'manual',    'OneSignal push tracking');

-- ---- TELEMETRY ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('telemetry.microsoft.com',    (SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','Windows telemetry'),
('vortex.data.microsoft.com',  (SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','Windows diagnostic data'),
('watson.telemetry.microsoft.com',(SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','Watson crash reporting'),
('settings-win.data.microsoft.com',(SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','Windows settings telemetry'),
('sqm.telemetry.microsoft.com',(SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','SQM telemetry'),
('oca.telemetry.microsoft.com',(SELECT id FROM dns_category WHERE slug='telemetry'),2,'Steven Black','OCA telemetry'),
('teredo.ipv6.microsoft.com',  (SELECT id FROM dns_category WHERE slug='telemetry'),1,'manual',     'Teredo mapping'),
('stats.adobe.com',            (SELECT id FROM dns_category WHERE slug='telemetry'),2,'EasyPrivacy', 'Adobe app telemetry'),
('metrics.apple.com',          (SELECT id FROM dns_category WHERE slug='telemetry'),2,'manual',      'Apple metrics'),
('securemetrics.apple.com',    (SELECT id FROM dns_category WHERE slug='telemetry'),2,'manual',      'Apple secure metrics'),
('api.apple-cloudkit.com',     (SELECT id FROM dns_category WHERE slug='telemetry'),1,'manual',      'Apple CloudKit sync'),
('events.data.linkedin.com',   (SELECT id FROM dns_category WHERE slug='telemetry'),2,'EasyPrivacy', 'LinkedIn data events'),
('analytics.tiktok.com',       (SELECT id FROM dns_category WHERE slug='telemetry'),3,'AdGuard DNS', 'TikTok analytics (privacy concern)'),
('log.byteoversea.com',        (SELECT id FROM dns_category WHERE slug='telemetry'),3,'AdGuard DNS', 'TikTok/ByteDance log server'),
('msa.lg.com',                 (SELECT id FROM dns_category WHERE slug='telemetry'),2,'OISD Full',   'LG smart TV telemetry'),
('ngfts.lge.com',              (SELECT id FROM dns_category WHERE slug='telemetry'),2,'OISD Full',   'LG firmware telemetry'),
('samsung.samsungrs.com',      (SELECT id FROM dns_category WHERE slug='telemetry'),2,'OISD Full',   'Samsung TV telemetry'),
('samsungacr.com',             (SELECT id FROM dns_category WHERE slug='telemetry'),3,'OISD Full',   'Samsung ACR (content recognition)'),
('vizio.com',                  (SELECT id FROM dns_category WHERE slug='telemetry'),3,'OISD Full',   'Vizio smart TV ACR/telemetry'),
('rokuads.com',                (SELECT id FROM dns_category WHERE slug='ad_network'),2,'OISD Full',  'Roku advertising'),
('scribe.logs.roku.com',       (SELECT id FROM dns_category WHERE slug='telemetry'),2,'OISD Full',   'Roku log endpoint');

-- ---- SOCIAL TRACKERS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('platform.twitter.com',       (SELECT id FROM dns_category WHERE slug='social_tracker'),2,'EasyPrivacy','Twitter widget / pixel'),
('ads.twitter.com',            (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'Twitter Ads'),
('analytics.twitter.com',      (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','Twitter analytics'),
('static.ads-twitter.com',     (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'Twitter ads static'),
('ads-api.twitter.com',        (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'Twitter ads API'),
('pixel.twitter.com',          (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','Twitter pixel'),
('linkedin.com',               (SELECT id FROM dns_category WHERE slug='social_tracker'),1,'manual',     'LinkedIn (social tracking when embedded)'),
('px.ads.linkedin.com',        (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'LinkedIn ad pixel'),
('snap.licdn.com',             (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','LinkedIn Insights tag'),
('bat.bing.com',               (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','Bing UET tracking'),
('ads.pinterest.com',          (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'Pinterest Ads'),
('ct.pinterest.com',           (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','Pinterest tag'),
('sc-static.net',              (SELECT id FROM dns_category WHERE slug='ad_network'),    2,'EasyList',   'Snapchat Ads static'),
('tr.snapchat.com',            (SELECT id FROM dns_category WHERE slug='tracking'),      2,'EasyPrivacy','Snapchat pixel'),
('ads.tiktok.com',             (SELECT id FROM dns_category WHERE slug='ad_network'),    3,'AdGuard DNS','TikTok Ads Manager');

-- ---- FINGERPRINTING ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('fingerprintjs.com',          (SELECT id FROM dns_category WHERE slug='fingerprinting'),3,'manual',    'FingerprintJS device ID'),
('api.fpjs.io',                (SELECT id FROM dns_category WHERE slug='fingerprinting'),3,'manual',    'FingerprintJS API'),
('cdn.deviceatlas.com',        (SELECT id FROM dns_category WHERE slug='fingerprinting'),3,'manual',    'DeviceAtlas fingerprint'),
('iovation.com',               (SELECT id FROM dns_category WHERE slug='fingerprinting'),3,'manual',    'iovation device risk'),
('threatmetrix.com',           (SELECT id FROM dns_category WHERE slug='fingerprinting'),3,'manual',    'ThreatMetrix device ID'),
('kaptcha.com',                (SELECT id FROM dns_category WHERE slug='fingerprinting'),2,'manual',    'Kochava fingerprint'),
('kochava.com',                (SELECT id FROM dns_category WHERE slug='tracking'),      3,'AdGuard DNS','Kochava mobile MMP');

-- ---- CRYPTOMINERS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('coinhive.com',               (SELECT id FROM dns_category WHERE slug='coin_hive'),    4,'NoCoin',     'Original CoinHive miner (defunct)'),
('cnhv.co',                    (SELECT id FROM dns_category WHERE slug='coin_hive'),    4,'NoCoin',     'CoinHive short domain'),
('coin-hive.com',              (SELECT id FROM dns_category WHERE slug='coin_hive'),    4,'NoCoin',     'CoinHive alt domain'),
('jsecoin.com',                (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'JSECoin browser miner'),
('monerominer.rocks',          (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'CoinBlockerLists','Monero miner'),
('crypto-loot.com',            (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'CryptoLoot miner'),
('2giga.link',                 (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'Miner disguise domain'),
('minero.pw',                  (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'Minero.pw miner'),
('webmine.pro',                (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'WebMine miner'),
('ppoi.org',                   (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'PPOI miner network'),
('static.hashing.host',        (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'Hashing.host static CDN'),
('hashing.win',                (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'Hashing.win miner'),
('coinlab.biz',                (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'NoCoin',     'CoinLab miner'),
('nbminer.com',                (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'CoinBlockerLists','NB Miner'),
('webmr.ru',                   (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'CoinBlockerLists','WebMR miner RU'),
('minerpool.pw',               (SELECT id FROM dns_category WHERE slug='cryptominer'),  4,'CoinBlockerLists','MinerPool miner');

-- ---- MALWARE / PHISHING (sampler — real lists run millions) ----
INSERT INTO dns_entry (domain, category_id, severity, source, subdomain_block, notes) VALUES
('malware-traffic-analysis.net',(SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',  TRUE, 'Known C2 test domain (reference)'),
('fakebank-secure.com',         (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Phishtank', TRUE, 'Fake bank phishing'),
('amazon-securelogin.net',      (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Phishtank', TRUE, 'Amazon phishing typosquat'),
('paypal-verify.info',          (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Phishtank', TRUE, 'PayPal phishing'),
('microsoft-support-alert.com', (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Phishtank', TRUE, 'Tech support scam'),
('apple-id-confirm.com',        (SELECT id FROM dns_category WHERE slug='phishing'), 5,'OpenPhish', TRUE, 'Apple ID phishing'),
('secure-netflixlogin.com',     (SELECT id FROM dns_category WHERE slug='phishing'), 5,'OpenPhish', TRUE, 'Netflix phishing'),
('fedex-track-parcel.com',      (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Spam404',   TRUE, 'FedEx phishing'),
('dhl-trackingservice.com',     (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Spam404',   TRUE, 'DHL phishing'),
('irs-taxrefund.com',           (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Spam404',   TRUE, 'IRS tax refund scam'),
('covid19-relief-fund.com',     (SELECT id FROM dns_category WHERE slug='phishing'), 5,'Spam404',   TRUE, 'COVID phishing'),
('crypto-wallet-restore.com',   (SELECT id FROM dns_category WHERE slug='phishing'), 5,'OpenPhish', TRUE, 'Crypto wallet drainer'),
('nft-minting-promo.xyz',       (SELECT id FROM dns_category WHERE slug='phishing'), 5,'manual',    TRUE, 'NFT mint phishing'),
('trojandownload.ru',           (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'Trojan dropper'),
('exploit-kit.cc',              (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'Exploit kit host'),
('emotet-c2.ru',                (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'Emotet C2'),
('cobalt-strike-beacon.net',    (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'Cobalt Strike C2'),
('lokibot-c2.cn',               (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'LokiBot C2'),
('redline-stealer.pro',         (SELECT id FROM dns_category WHERE slug='malware'),  5,'URLhaus',   TRUE, 'RedLine stealer C2'),
('ransomware-decrypt.top',      (SELECT id FROM dns_category WHERE slug='ransomware'),5,'manual',   TRUE, 'Ransomware ransom page'),
('lockbit-support.onion.ws',    (SELECT id FROM dns_category WHERE slug='ransomware'),5,'manual',   TRUE, 'LockBit clearnet mirror'),
('conti-news.cc',               (SELECT id FROM dns_category WHERE slug='ransomware'),5,'manual',   TRUE, 'Conti ransomware (defunct)');

-- ---- PUP / ADWARE ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('superfish.com',              (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Superfish adware (Lenovo)'),
('browsefox.com',              (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'BrowseFox PUP'),
('conduit.com',                (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Conduit toolbar'),
('sweetim.com',                (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'SweetIM toolbar'),
('snapdo.com',                 (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Snap.do browser hijacker'),
('delta-search.com',           (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Delta Search hijacker'),
('babylon.com',                (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Babylon toolbar'),
('Ask.com',                    (SELECT id FROM dns_category WHERE slug='pup'),2,'manual',    'Ask toolbar bundler'),
('mywebsearch.com',            (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'MyWebSearch toolbar'),
('searchqu.com',               (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'Searchqu hijacker'),
('istart.webssearches.com',    (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'WebSearches hijacker'),
('dosearches.com',             (SELECT id FROM dns_category WHERE slug='pup'),3,'manual',    'DoSearches hijacker');

-- ---- POP-UNDER / POP-UP NETWORKS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('popcash.net',                (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','PopCash pop-under network'),
('popads.net',                 (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','PopAds network'),
('propellerads.com',           (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','PropellerAds pop-under'),
('advertiserhq.com',           (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','AdvertiserHQ pop-under'),
('clickadu.com',               (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','ClickAdu network'),
('adsterra.com',               (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','Adsterra network'),
('trafficfactory.biz',         (SELECT id FROM dns_category WHERE slug='pop_under'),3,'EasyList','TrafficFactory (adult traffic)'),
('juicyads.com',               (SELECT id FROM dns_category WHERE slug='adult'),    2,'EasyList','JuicyAds adult ad network'),
('exoclick.com',               (SELECT id FROM dns_category WHERE slug='adult'),    2,'EasyList','ExoClick adult network'),
('trafficjunky.com',           (SELECT id FROM dns_category WHERE slug='adult'),    2,'EasyList','TrafficJunky adult network'),
('ero-advertising.com',        (SELECT id FROM dns_category WHERE slug='adult'),    2,'EasyList','Ero-Advertising adult'),
('adhitz.com',                 (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','AdHitz pop network'),
('mgid.com',                   (SELECT id FROM dns_category WHERE slug='ad_network'),2,'EasyList','MGID native ads'),
('hilltopads.net',             (SELECT id FROM dns_category WHERE slug='pop_under'),2,'EasyList','HilltopAds network');

-- ---- CLICK FRAUD ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('revcontent.com',             (SELECT id FROM dns_category WHERE slug='click_fraud'),3,'EasyList','RevContent (IVT concerns)'),
('bouncexchange.com',          (SELECT id FROM dns_category WHERE slug='tracking'),  2,'EasyPrivacy','BounceX intent-based pop'),
('justpremium.com',            (SELECT id FROM dns_category WHERE slug='ad_network'),2,'EasyList','JustPremium high-impact ads'),
('fout.jp',                    (SELECT id FROM dns_category WHERE slug='click_fraud'),3,'AdGuard DNS','Japanese click fraud'),
('eclick.vn',                  (SELECT id FROM dns_category WHERE slug='click_fraud'),3,'manual',   'Vietnamese click fraud'),
('traffboost.net',             (SELECT id FROM dns_category WHERE slug='click_fraud'),4,'manual',   'Click fraud botnet'),
('ads2buy.com',                (SELECT id FROM dns_category WHERE slug='click_fraud'),4,'manual',   'Click fraud domain');

-- ---- DATA BROKERS ----
INSERT INTO dns_entry (domain, category_id, severity, source, notes) VALUES
('spokeo.com',                 (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'Spokeo people search'),
('whitepages.com',             (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'WhitePages data broker'),
('intelius.com',               (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'Intelius people finder'),
('peoplefinders.com',          (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'PeopleFinders broker'),
('checkpeople.com',            (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'CheckPeople broker'),
('beenverified.com',           (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'BeenVerified broker'),
('instantcheckmate.com',       (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'Instant Checkmate'),
('truthfinder.com',            (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'TruthFinder broker'),
('experian.com',               (SELECT id FROM dns_category WHERE slug='data_broker'),2,'manual',   'Experian data (marketing arm)'),
('datalogix.com',              (SELECT id FROM dns_category WHERE slug='data_broker'),3,'manual',   'Datalogix (Oracle Data Cloud)'),
('nielsen.com',                (SELECT id FROM dns_category WHERE slug='data_broker'),2,'manual',   'Nielsen audience data');

-- ============================================================
--  USEFUL VIEWS
-- ============================================================

CREATE OR REPLACE VIEW v_blocklist_full AS
SELECT
    de.domain,
    de.subdomain_block,
    dc.slug AS category_slug,
    dc.label AS category,
    dc.severity AS category_severity,
    de.severity AS entry_severity,
    de.source,
    de.is_active,
    de.notes,
    de.first_seen,
    de.created_at
FROM dns_entry de
JOIN dns_category dc ON dc.id = de.category_id
ORDER BY de.severity DESC, dc.slug, de.domain;

CREATE OR REPLACE VIEW v_high_severity AS
SELECT domain, category_id, severity, source, notes
FROM dns_entry
WHERE severity >= 4 AND is_active = TRUE
ORDER BY severity DESC, domain;

CREATE OR REPLACE VIEW v_stats_by_category AS
SELECT
    dc.label,
    dc.severity AS cat_severity,
    COUNT(de.id) AS total_entries,
    COUNT(de.id) FILTER (WHERE de.is_active) AS active_entries
FROM dns_category dc
LEFT JOIN dns_entry de ON de.category_id = dc.id
GROUP BY dc.id, dc.label, dc.severity
ORDER BY total_entries DESC;

-- Quick lookup: is this domain blocked?
CREATE OR REPLACE FUNCTION is_domain_blocked(p_domain TEXT)
RETURNS TABLE (
    is_blocked BOOLEAN,
    category TEXT,
    severity SMALLINT,
    subdomain_block BOOLEAN,
    source TEXT
) LANGUAGE sql STABLE AS $$
    SELECT
        TRUE,
        dc.label::TEXT,
        de.severity,
        de.subdomain_block,
        de.source::TEXT
    FROM dns_entry de
    JOIN dns_category dc ON dc.id = de.category_id
    WHERE de.domain = p_domain
      AND de.is_active = TRUE
    LIMIT 1;
$$;

-- Check including wildcard parent match
CREATE OR REPLACE FUNCTION is_domain_blocked_wildcard(p_domain TEXT)
RETURNS TABLE (
    is_blocked BOOLEAN,
    matched_rule TEXT,
    category TEXT,
    severity SMALLINT
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_parts TEXT[];
    v_candidate TEXT;
    v_rec RECORD;
    i INT;
BEGIN
    v_parts := string_to_array(p_domain, '.');
    FOR i IN 1 .. array_length(v_parts, 1) LOOP
        v_candidate := array_to_string(v_parts[i:array_length(v_parts,1)], '.');
        SELECT de.domain, dc.label, de.severity
          INTO v_rec
          FROM dns_entry de
          JOIN dns_category dc ON dc.id = de.category_id
         WHERE de.domain = v_candidate
           AND de.is_active = TRUE
           AND (de.subdomain_block = TRUE OR v_candidate = p_domain)
         LIMIT 1;
        IF FOUND THEN
            RETURN QUERY SELECT TRUE, v_rec.domain::TEXT, v_rec.label::TEXT, v_rec.severity;
            RETURN;
        END IF;
    END LOOP;
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, NULL::SMALLINT;
END;
$$;

-- ============================================================
--  INDEX ON FEEDS
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_dns_entry_source
    ON dns_entry (source);

-- ============================================================
--  QUICK STATS QUERY  (run to verify install)
-- ============================================================
-- SELECT * FROM v_stats_by_category;
-- SELECT * FROM is_domain_blocked('doubleclick.net');
-- SELECT * FROM is_domain_blocked_wildcard('static.js.doubleclick.net');
