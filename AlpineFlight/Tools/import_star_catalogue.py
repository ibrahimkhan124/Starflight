#!/usr/bin/env python3
"""Build the offline catalogue from NASA HEASARC's ESA Hipparcos TAP service.
No runtime network/API key. J1991.25 ICRS, positive parallax, relative error < 50%.
"""
import base64, hashlib, json, math, struct, urllib.parse, urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
QUERY = 'SELECT TOP 3000 hip_number,ra,dec,vmag,parallax,bv_color,parallax_error FROM hipparcos WHERE vmag < 7 AND parallax > 0 AND parallax_error < 0.5 * parallax ORDER BY vmag,hip_number'
URL = 'https://heasarc.gsfc.nasa.gov/xamin/vo/tap/sync?'+urllib.parse.urlencode(dict(REQUEST='doQuery',LANG='ADQL',QUERY=QUERY))
ROOT = Path(__file__).resolve().parents[1]
NAMES = {32349:'Sirius',27989:'Betelgeuse',24436:'Rigel',11767:'Polaris',69673:'Arcturus',30438:'Canopus',71683:'Alpha Centauri',91262:'Vega',24608:'Capella',37279:'Procyon',97649:'Altair',65474:'Spica',80763:'Antares',21421:'Aldebaran',37826:'Pollux',49669:'Regulus',113368:'Fomalhaut'}
def build(data):
    root = ET.fromstring(data); ns={'v':'http://www.ivoa.net/xml/VOTable/v1.3'}
    assert not any(i.attrib.get('value') == 'ERROR' for i in root.findall('.//v:INFO',ns)),data[:2000]
    fields = root.findall('.//v:FIELD',ns)
    assert [f.attrib['datatype'] for f in fields] == ['int']+['double']*6
    raw = base64.b64decode(root.find('.//v:STREAM',ns).text)
    stars=[]
    for hip,ra,dec,mag,plx,bv,err in struct.iter_unpack('>idddddd',raw):
        assert all(map(math.isfinite,[ra,dec,mag,plx,err])) and plx>0 and 0<=ra<360 and -90<=dec<=90
        stars.append(dict(hip=hip,name=NAMES.get(hip),raDegrees=ra,decDegrees=dec,magnitude=mag,parallaxMas=plx,parallaxErrorMas=err,bv=bv if math.isfinite(bv) else 0.65))
    assert len(stars)==3000 and len({s['hip'] for s in stars})==3000
    assert {32349,27989,24436,11767}.issubset({s['hip'] for s in stars})
    folder=ROOT/'AlpineFlight/Resources/Astronomy';folder.mkdir(parents=True,exist_ok=True)
    output=json.dumps(stars,separators=(',',':'),allow_nan=False).encode()
    (folder/'hipparcos-bright.json').write_bytes(output)
    (folder/'provenance.json').write_text(json.dumps(dict(catalogue='ESA Hipparcos (1997), CDS I/239, via NASA HEASARC',source='https://heasarc.gsfc.nasa.gov/w3browse/all/hipparcos.html',query=QUERY,coordinateEpoch='J1991.25 ICRS; no proper-motion extrapolation',distance='1000 / parallax_mas in parsecs; approximate inverse-parallax distances, relative parallax error below 50%',colour='B-V colour; missing colours use neutral 0.65',count=3000,sha256=hashlib.sha256(output).hexdigest()),indent=2)+'\n')
    print('Prepared',len(stars),'catalogued stars;',len(output),'bytes')
if __name__=='__main__':
    import sys
    data=Path(sys.argv[1]).read_bytes() if len(sys.argv)>1 else urllib.request.urlopen(URL,timeout=45).read()
    build(data)
