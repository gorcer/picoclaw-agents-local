"""
Flask proxy for Yandex SpeechKit TTS/STT
Converts OpenAI-compatible requests to Yandex SpeechKit API (old v1 API)
"""
import os
import base64
import requests
from flask import Flask, request, jsonify, Response
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

YANDEX_API_KEY = os.environ.get('YANDEX_API_KEY', '')
YANDEX_FOLDER_ID = os.environ.get('YANDEX_FOLDER_ID', '')


@app.route('/v1/audio/speech', methods=['POST'])
def tts():
    """OpenAI TTS → Yandex TTS (old v1 API)"""
    data = request.json
    text = data.get('input', data.get('text', ''))
    voice = data.get('voice', 'jane')
    
    url = f"https://tts.api.cloud.yandex.net/speech/v1/tts:synthesize"
    headers = {'Authorization': f'Api-Key {YANDEX_API_KEY}'}
    
    params = {
        'folderId': YANDEX_FOLDER_ID,
        'text': text,
        'lang': 'ru-RU',
        'voice': voice,
        'format': 'mp3'
    }
    
    response = requests.post(url, headers=headers, params=params)
    
    if response.status_code == 200:
        return Response(response.content, mimetype='audio/mpeg')
    else:
        return jsonify({'error': response.text}), response.status_code


@app.route('/v1/audio/transcriptions', methods=['POST'])
def stt():
    """OpenAI STT → Yandex STT (old v1 API) - expects oggopus format"""
    if 'file' in request.files:
        audio_data = request.files['file'].read()
        content_type = request.files['file'].content_type
    else:
        data = request.json
        b64_audio = data.get('file', data.get('audio'))
        if b64_audio:
            audio_data = base64.b64decode(b64_audio)
        else:
            return jsonify({'error': 'No audio data'}), 400
    
    url = f"https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId={YANDEX_FOLDER_ID}&lang=ru-RU"
    headers = {'Authorization': f'Api-Key {YANDEX_API_KEY}'}
    
    response = requests.post(url, headers=headers, data=audio_data)
    
    if response.status_code == 200:
        result = response.json()
        return jsonify({'text': result.get('result', '')})
    else:
        return jsonify({'error': response.text}), response.status_code


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8002)))
