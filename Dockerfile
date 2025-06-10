#######################################################################
#  ComfyUI worker – base Torch 2.4 / CUDA 12.4 / Python 3.11 template #
#######################################################################
# --> dispo sur Docker Hub depuis l'« official PyTorch 2.4 + cu124 »
#     template de RunPod (même tagging que la variante "-base")
FROM runpod/worker-comfyui:5.1.0-base

# 1) dépendances système – ajout python3.12-dev
RUN apt-get update && \
    # on essaye python3.12-dev; si le paquet n'existe pas, on bascule sur python3-dev
    (apt-get install -y --no-install-recommends python3.12-dev || \
     apt-get install -y --no-install-recommends python3-dev) && \
    apt-get install -y --no-install-recommends \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
        build-essential cmake pkg-config && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


#############################################
# 2) custom-nodes (inchangé, juste replié)  #
#############################################
RUN set -eux; \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack        /opt/ComfyUI/custom_nodes/Impact-Pack && \
    git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui  /opt/ComfyUI/custom_nodes/was-node-suite-comfyui && \
    git clone --depth 1 https://github.com/WainWong/ComfyUI-Loop-image         /opt/ComfyUI/custom_nodes/Loop-Image && \
    git clone --depth 1 https://github.com/liusida/ComfyUI-AutoCropFaces       /opt/ComfyUI/custom_nodes/AutoCropFaces && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack     /opt/ComfyUI/custom_nodes/Impact-Subpack && \
    git clone --depth 1 https://github.com/chrisgoringe/cg-use-everywhere      /opt/ComfyUI/custom_nodes/cg-use-everywhere && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials            /opt/ComfyUI/custom_nodes/ComfyUI_essentials && \
    git clone --depth 1 https://github.com/MixLabPro/comfyui-mixlab-nodes      /opt/ComfyUI/custom_nodes/comfyui-mixlab-nodes && \
    git clone --depth 1 https://github.com/SeaArtLab/comfyui_storydiffusion    /opt/ComfyUI/custom_nodes/StoryDiffusion && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus        /opt/ComfyUI/custom_nodes/ComfyUI_IPAdapter_plus

#############################################
# 3) requirements.txt de chaque custom node #
#############################################
RUN for node in Impact-Pack StoryDiffusion Loop-Image AutoCropFaces Impact-Subpack \
                cg-use-everywhere ComfyUI_essentials comfyui-mixlab-nodes ComfyUI_IPAdapter_plus; do \
        req="/opt/ComfyUI/custom_nodes/${node}/requirements.txt"; \
        if [ -f "$req" ]; then pip install --no-cache-dir -r "$req"; fi; \
    done

#############################################
# 4) upgrade pip + setuptools (Py 3.11 OK)  #
#############################################
RUN python -m pip install --no-cache-dir -U pip setuptools wheel

########################################################
# 5) libs GPU sensibles – versions compatibles cu 12.4 #
########################################################
# On installe les paquets par petits groupes pour mieux
# identifier les erreurs de compilation ou de dépendances.

# xformers (très dépendant de la version de torch)
RUN python -m pip install --no-cache-dir "xformers==0.0.28.post1"

# onnxruntime (pour l'inférence ONNX sur GPU)
RUN python -m pip install --no-cache-dir "onnxruntime-gpu-cu12==1.18.1" onnx

# bitsandbytes (pour la quantification, souvent source d'erreurs de compilation)
RUN python -m pip install --no-cache-dir bitsandbytes

# insightface et ses dépendances directes
RUN python -m pip install --no-cache-dir insightface==0.7.3 opencv-python-headless facexlib

# Écosystème Hugging Face
RUN python -m pip install --no-cache-dir \
    accelerate \
    "diffusers>=0.27" \
    "transformers>=4.39" \
    safetensors \
    peft \
    sentencepiece

# Autres bibliothèques de deep learning
RUN python -m pip install --no-cache-dir \
    "timm>=0.9.12" \
    ultralytics \
    kornia \
    einops \
    pytorch_lightning

# Uninstall torchaudio to prevent startup crash from version mismatch
RUN python -m pip uninstall -y torchaudio

########################################################
# 6) liens symboliques vers /runpod-volume (création du dossier puis liens) #
########################################################
RUN mkdir -p /opt/ComfyUI/models && \
    ln -s /runpod-volume/checkpoints  /opt/ComfyUI/models/checkpoints && \
    ln -s /runpod-volume/vae          /opt/ComfyUI/models/vae && \
    ln -s /runpod-volume/loras        /opt/ComfyUI/models/loras && \
    ln -s /runpod-volume/controlnet   /opt/ComfyUI/models/controlnet && \
    ln -s /runpod-volume/ipadapter    /opt/ComfyUI/models/ipadapter && \
    ln -s /runpod-volume/ultralytics  /opt/ComfyUI/models/ultralytics && \
    ln -s /runpod-volume/sam          /opt/ComfyUI/models/sam && \
    ln -s /runpod-volume/embeddings   /opt/ComfyUI/models/embeddings && \
    ln -s /runpod-volume/clip_vision  /opt/ComfyUI/models/clip_vision

###########################
# 7) extra model paths     #
###########################
COPY extra_model_paths.yaml /opt/ComfyUI/extra_model_paths.yaml