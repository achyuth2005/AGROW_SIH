# 🚀 Fresh Deployment Guide

Follow these steps EXACTLY to deploy your backend from scratch.

## 1. Create a New Space
1. Go to [Hugging Face Spaces](https://huggingface.co/spaces).
2. Click **"Create new Space"**.
3. Name it something new (e.g., `AGROW-Backend-V2`).
4. Select **Docker** as the SDK.
5. Click **Create Space**.

## 2. Upload Files
Upload ONLY these files from your `hf_deploy/SAR-Analysis` folder to the "Files" tab of your new Space:
- `app.py`
- `SAR_prediction.py`
- `feature_engineering.py`
- `clustering.py`
- `gemini_llm_integration.py`
- `requirements.txt`
- `Dockerfile`

> **Note:** Do NOT upload `.env` or `__pycache__`.

## 3. Set Secrets (Crucial Step!)
Go to **Settings -> Variables and secrets** and add these 3 secrets.
**Copy the values EXACTLY. Do not add any spaces.**

| Name | Value |
|------|-------|
| `SH_CLIENT_ID` | `sh-709c1173-fc33-4a0e-90e4-b84161ed5b9d` |
| `SH_CLIENT_SECRET` | `IdopxGFFr3NKFJ4Y2ywJRVfmM5eBB9b4` |
| `GEMINI_API_KEY` | `your_gemini_api_key_here` |

## 4. Update App
Once the Space is "Running", copy the **Direct URL** (click the 3 dots > Embed this space > Direct URL).
Update `lib/services/sar_analysis_service.dart` with this new URL.
