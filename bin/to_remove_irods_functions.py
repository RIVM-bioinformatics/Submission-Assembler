import os, requests, ssl, re, argparse, time, yaml
from irods.session import iRODSSession
from irods.models import Collection, DataObjectMeta, DataObject, CollectionMeta
from irods.column import Criterion

cert='/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem'

def irodsConnect(irodsfile="", use_ssl=False, **kwargs):
    """Connect to irods iCAT and return iRODSSession object
        irodsfile: irods environment file to use.
        use_ssl: use ssl if True

    Returns:
        iRODSSession object
    """
    if irodsfile:
        envFile = irodsfile
    else:
        try:
            envFile = os.environ['IRODS_ENVIRONMENT_FILE']
        except KeyError:
            envFile = os.path.expanduser('~/.irods/irods_environment.json')

    if use_ssl:
        context = ssl._create_unverified_context(purpose=ssl.Purpose.SERVER_AUTH,
                                                cafile=None, capath=None, cadata=None)
        ssl_settings = {'irods_ssl_ca_certificate_file': '/etc/irods/ssl/irods.crt',
                        'ssl_context': context}
        session = iRODSSession(irods_env_file=envFile,
                               **ssl_settings, **kwargs)
    else:
        session = iRODSSession(irods_env_file=envFile, **kwargs)
    return session
# irodsConnect()

try:
    env_file = os.environ['IRODS_ENVIRONMENT_FILE']
except KeyError:
    env_file = os.path.expanduser('~/.irods/irods_environment.json')
ssl_settings = {} # Or, optionally: {'ssl_context': <user_customized_SSLContext>}
# env_file = os.path.expanduser('~/.irods/irods_environment.json')

def rest_call(url):
    response = requests.get(url, verify=cert)
    try:
        return_data = response.json()
    except:
        raise Exception("url '{}' gives no json data".format(url))
    return return_data, response.status_code

def ExtractFromjson(nanopore_basename_dir):
    run_bar_key_list = []
    list_isolate_key = []
    server="http://rivm-biofl-l01p.rivm.ssc-campus.nl"
    FLOWCELLID = nanopore_basename_dir.split('/')[-1].split('_')[3]
    request = server + "/ngsruns/api/runs/" + FLOWCELLID
    runinfo, response = rest_call(request)
    if not runinfo or response != 200:
        return False
    run_prefix = runinfo["name"]
    request = server + "/ngsruns/api/runs/" + FLOWCELLID + "/barcodes"
    barcodes, response = rest_call(request)
    if not barcodes or response != 200:
        return False
    for item in barcodes:
        barcode = item["barcode"]
        key = item["sampleid"]
        run_bar_key_list.append(f"{run_prefix}_{barcode}_{key}")
        list_isolate_key.append(key)
    return list_isolate_key, run_bar_key_list

def get_usercfg_h():
    # with irodsConnect() as session:
    with iRODSSession(irods_env_file=env_file) as session:
        print(f"Searching iRODS1")
        if not session.data_objects.exists(f"/rivmZone/projects/bsr_amr/config/user.yaml"):
            print(f"No access or config file for project bsr_amr - run iinit and try again.")
            return False
        else:
            result = session.data_objects.get(f"/rivmZone/projects/bsr_amr/config/user.yaml")
            with result.open('r+') as f:
                configread = f.read()
                configyml = yaml.safe_load(configread)
                return configyml

def irods_for_html_report(basedir):
    if basedir == 'NO_DIR':
        return 'no_file', False
    else:
        # with irodsConnect() as session:
        with iRODSSession(irods_env_file=env_file) as session:
            print(f"Searching iRODS for html report", end=' ')
            q = session.query(Collection.name, DataObject).filter(
                Criterion('like', Collection.name, f"/rivmZone/projects/ngslab/minion/{basedir}")).filter(
                Criterion('like', DataObject.name, f"report%.html"))
            result = [ (r[Collection.name], r[DataObject.name]) for r in q]
            if len(result) == 0:
                print('nothing found :(')
            else:
                print('... found!')
                filename = f"{result[0][1]}"
                irods_path = f"{result[0][0]}/{result[0][1]}"
                return filename, irods_path


def irods_for_sequence_sum(basedir):
    if basedir == 'NO_DIR':
        return 'no_sequencing_summary.html', False
    else:
        # with irodsConnect() as session:
        with iRODSSession(irods_env_file=env_file) as session:
            print(f"Searching iRODS for sequence summary", end=' ')
            q = session.query(Collection.name, CollectionMeta).filter(
                Criterion('like', Collection.name, f"/rivmZone/projects/ngslab/minion/{basedir}")).filter(
                Criterion('=', CollectionMeta.name, 'minion::sequencing_summary_file'))
            result = [ (r[Collection.name], r[CollectionMeta.value]) for r in q]
            if len(result) == 0:
                print('nothing found :(')
            else:
                print('... found!')
                filename = f"{result[0][1]}"
                irods_path = f"{result[0][0]}/{result[0][1]}"
                return filename, irods_path
