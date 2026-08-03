import jwt, time, requests, os, hashlib

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
APP_ID = os.environ.get('APP_ID', '')  # ASCアプリ作成後に設定
KEY_PATH = '/tmp/asc_key.p8'

p8 = open(KEY_PATH).read()

def make_token():
    return jwt.encode(
        {'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
        p8, algorithm='ES256', headers={'kid': KEY_ID}
    )

def api(method, path, **kwargs):
    url = f'https://api.appstoreconnect.apple.com/v1{path}' if path.startswith('/') else path
    headers = {'Authorization': f'Bearer {make_token()}', 'Content-Type': 'application/json'}
    r = requests.request(method, url, headers=headers, **kwargs)
    print(f'  {method} {path} -> {r.status_code}')
    if r.status_code >= 400:
        print(f'    ERROR: {r.text[:500]}')
    return r

def upload_file(set_id, filepath):
    fname = os.path.basename(filepath)
    filesize = os.path.getsize(filepath)
    with open(filepath, 'rb') as f:
        data = f.read()
    checksum = hashlib.md5(data).hexdigest()
    print(f'  Uploading {fname} ({filesize} bytes)...')
    r = api('POST', '/appScreenshots', json={'data': {
        'type': 'appScreenshots',
        'attributes': {'fileName': fname, 'fileSize': filesize},
        'relationships': {
            'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': set_id}}
        }
    }})
    if r.status_code != 201:
        return
    ss = r.json()['data']
    ss_id = ss['id']
    for op in ss['attributes']['uploadOperations']:
        req_headers = {h['name']: h['value'] for h in op['requestHeaders']}
        chunk = data[op['offset']:op['offset'] + op['length']]
        requests.put(op['url'], headers=req_headers, data=chunk)
    api('PATCH', f'/appScreenshots/{ss_id}', json={'data': {
        'type': 'appScreenshots', 'id': ss_id,
        'attributes': {'sourceFileChecksum': checksum, 'uploaded': True}
    }})

# iPad 12.9 3GEN and 6GEN share the same image.
DISPLAY_TYPES = [
    ('APP_IPHONE_67', 'iphone_67'),
    ('APP_IPAD_PRO_3GEN_129', 'ipad_129'),
    ('APP_IPAD_PRO_6GEN_129', 'ipad_129'),
]

screenshot_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'screenshots')
modes = ['1', '2', '3', '4']

r = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=1')
version_id = r.json()['data'][0]['id']
print(f'Version: {version_id}')

r = api('GET', f'/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=10')
locs = r.json()['data']

for loc in locs:
    loc_id = loc['id']
    locale = loc['attributes']['locale']
    print(f'\n=== {locale} ({loc_id}) ===')

    r = api('GET', f'/appStoreVersionLocalizations/{loc_id}/appScreenshotSets')
    for s in r.json().get('data', []):
        api('DELETE', f'/appScreenshotSets/{s["id"]}')

    for display_type, prefix in DISPLAY_TYPES:
        files = [os.path.join(screenshot_dir, f'{prefix}_{m}.png') for m in modes]
        if not all(os.path.exists(f) for f in files):
            print(f'  Skipping {display_type} (missing files)')
            continue
        r = api('POST', '/appScreenshotSets', json={'data': {
            'type': 'appScreenshotSets',
            'attributes': {'screenshotDisplayType': display_type},
            'relationships': {
                'appStoreVersionLocalization': {
                    'data': {'type': 'appStoreVersionLocalizations', 'id': loc_id}
                }
            }
        }})
        if r.status_code not in (200, 201):
            continue
        set_id = r.json()['data']['id']
        for f in files:
            upload_file(set_id, f)

print('\nDone!')
