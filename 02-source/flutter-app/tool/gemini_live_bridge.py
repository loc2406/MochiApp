#!/usr/bin/env python3
"""Device-specific Gemini UI bridge. Requires paired ADB and uiautomator2.
No private APIs, history sidebar traversal, public sharing, or background recording.
Live runs on the phone. This controller MUST remain running on the paired computer.
"""
import argparse, base64, hashlib, json, re, subprocess, time
from pathlib import Path
import xml.etree.ElementTree as ET
import uiautomator2 as u2
GOOGLE = 'com.google.android.googlequicksearchbox'
MOCHI = 'com.mochi.study.mochi_app'
ADB = '/home/ben/android-env/sdk/platform-tools/adb'
END = ['Kết thúc chế độ Live', 'End Live', 'End live']
CAMERA = ['Bật/tắt camera', 'Toggle camera']

class Bridge:
    def __init__(self, serial, output):
        self.serial, self.output = serial, Path(output)
        self.output.mkdir(parents=True, exist_ok=True)
        self.d = u2.connect(serial)
        self.d.jsonrpc.setConfigurator({'waitForIdleTimeout': 0, 'waitForSelectorTimeout': 0})
    def adb(self, *args):
        return subprocess.check_output([ADB, '-s', self.serial, *args], text=True, timeout=30)
    def tree(self):
        focus = self.adb('shell', 'dumpsys', 'window')
        if not any('mCurrentFocus=' in line and GOOGLE + '/' in line for line in focus.splitlines()):
            raise RuntimeError('Gemini is not focused. Pausing, no taps sent.')
        return ET.fromstring(self.d.dump_hierarchy())
    @staticmethod
    def find(root, labels):
        return next((n for n in root.iter('node') if n.get('package') == GOOGLE
                     and (n.get('content-desc') in labels or n.get('text') in labels)), None)
    def click(self, labels, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            root = self.tree(); node = self.find(root, labels)
            if node is not None:
                # Resolve by semantic label each time, so rotation changes are safe.
                description = node.get('content-desc')
                selector = self.d(description=description) if description else self.d(text=node.get('text'))
                selector.click(timeout=2)
                return
            time.sleep(.4)
        raise RuntimeError('Expected control missing: ' + ', '.join(labels))
    def start(self):
        self.adb('shell', 'am', 'start', '-n', 'com.google.android.apps.bard/.shellapp.BardEntryPointActivity')
        time.sleep(1)
        root = self.tree()
        # Never resume a previous chat and mistake its history for a new session.
        new = self.find(root, ['Cuộc trò chuyện mới', 'New chat'])
        if new is not None:
            self.click(['Cuộc trò chuyện mới', 'New chat']); time.sleep(.5)
        elif any(n.get('resource-id', '').endswith('/assistant_robin_user_message_text') for n in root.iter('node')):
            raise RuntimeError('Existing conversation detected; cannot safely create a fresh session.')
        self.click(['Open Gemini Live', 'Mở Gemini Live'])
        self.click(CAMERA)
        print('LIVE_CAMERA_TOGGLE_SENT; verify device preview; no video is recorded by bridge', flush=True)
    def wait_end(self, timeout=600):
        start = time.monotonic(); seen_live = False
        interrupted_at = None
        while time.monotonic() - start < timeout:
            try:
                root = self.tree()
            except RuntimeError:
                interrupted_at = interrupted_at or time.monotonic()
                if time.monotonic() - interrupted_at > 10:
                    raise RuntimeError('App interrupted for over 10 seconds; disarmed to avoid importing another conversation.')
                time.sleep(1); continue
            interrupted_at = None
            if self.find(root, END) is not None:
                seen_live = True
            elif seen_live and any(n.get('resource-id','').endswith('/assistant_robin_text') for n in root.iter('node')):
                time.sleep(1)
                return self.capture()
            time.sleep(.8)
        raise TimeoutError('No verified end of this Live session. Nothing imported; check phone to stop Live.')
    def capture(self):
        pages = []; fingerprints = set()
        for page in range(24):
            root = self.tree()
            if self.find(root, END) is not None:
                raise RuntimeError('Live still active; finish the session first.')
            items = []
            for node in root.iter('node'):
                rid, text = node.get('resource-id',''), node.get('text','').strip()
                if node.get('package') != GOOGLE or not text: continue
                role = 'user' if rid.endswith('/assistant_robin_user_message_text') else 'assistant' if rid.endswith('/assistant_robin_text') else None
                if role: items.append({'role': role, 'content': text})
            fingerprint = json.dumps(items, ensure_ascii=False)
            if fingerprint in fingerprints: break
            fingerprints.add(fingerprint); pages.append(items)
            scroll = self.d(resourceId=GOOGLE + ':id/assistant_robin_chat_history_list')
            if not scroll.exists: break
            try:
                if not scroll.scroll.backward(steps=20): break
            except Exception: break
            time.sleep(.25)
        messages = []
        for items in reversed(pages):
            # Merge overlapping visible pages without blindly deduplicating repeated words.
            overlap = 0
            for k in range(1, min(len(messages),len(items))+1):
                if messages[-k:] == items[:k]: overlap = k
            messages.extend(items[overlap:])
        if not messages: raise RuntimeError('No transcript available. Nothing imported.')
        digest = hashlib.sha256(json.dumps(messages,ensure_ascii=False).encode()).hexdigest()[:24]
        session = {'schema':'mochi.live.v1', 'id':digest, 'source':'gemini_app_ui',
                   'capturedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
                   'complete':False, 'messages':messages,
                   'limitations':['Visible text only; no camera content or audio recording',
                                  'Gemini may omit or virtualize earlier utterances; completeness not guaranteed']}
        path = self.output / (digest + '.json')
        path.write_text(json.dumps(session,ensure_ascii=False,indent=2))
        print('CAPTURED',len(messages),'messages',path,flush=True)
        return path
    def send(self, path):
        raw = Path(path).read_bytes()
        if len(raw)>65000: raise RuntimeError('Transcript too large for one Intent; no truncation performed')
        encoded = base64.b64encode(raw).decode()
        result = self.adb('shell','am','start','-n',MOCHI+'/.MainActivity',
                         '-a','com.mochi.study.IMPORT_LIVE_SESSION','--es','session_b64',encoded)
        print(result,flush=True)
    def watch(self):
        print('WAITING for explicit MOCHI camera-button tickets. No UI/history scanning while idle.',flush=True)
        path = '/sdcard/Android/data/' + MOCHI + '/files/live_bridge_request.txt'
        seen = ''
        while True:
            try:
                res = self.adb('shell', 'cat', path).strip()
                ticket = res if res.isdigit() else ''
            except subprocess.CalledProcessError:
                time.sleep(1); continue
            if ticket and ticket != seen and ticket.isdigit():
                seen = ticket
                print('TICKET_RECEIVED', ticket, flush=True)
                # Never replay a stale launch ticket after reconnect/restart.
                if abs(time.time() - int(ticket)/1000) < 60:
                    try:
                        self.start(); self.send(self.wait_end())
                    except Exception as e: print('BRIDGE_STOP',type(e).__name__,str(e),flush=True)
            time.sleep(.8)

def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['start','capture','run','watch','send']);p.add_argument('--serial',required=True);p.add_argument('--output',default='/home/ben/mochi_delivery/live-bridge/sessions');p.add_argument('--file');a=p.parse_args();b=Bridge(a.serial,a.output)
    if a.command=='start':b.start()
    elif a.command=='capture':b.capture()
    elif a.command=='send':b.send(a.file)
    elif a.command=='run':b.start();b.send(b.wait_end())
    elif a.command=='watch':b.watch()
if __name__=='__main__':main()
