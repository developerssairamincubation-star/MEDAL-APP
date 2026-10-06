# YOLO Model Training & Custom Dataset Guide for MEDAL

This guide documents the procedures for training, evaluating, and deploying a custom MEDAL civic object detection model (target filename: `medal_yolo26.pt`) using Ultralytics YOLO.

> **Status Notice:**  
> The current MEDAL production deployment uses the pretrained base model (`models/yolo26n.pt` / YOLO11n weights) paired with an intelligent multi-object heuristic classification engine. A custom dataset has **not** yet been trained for this deployment. Follow the instructions below when the MEDAL dataset collection phase is complete.

---

## 1. Custom Civic Classes

The future custom model targets 10 civic issue categories directly:

| Class ID | Class Name | Human Description | Primary SDGs |
|:---|:---|:---|:---|
| 0 | `waste_dumping` | Overflowing garbage, uncollected waste heaps, illegal dumping | SDG 11, SDG 12 |
| 1 | `road_damage` | Potholes, cracked asphalt, road subsidence | SDG 9, SDG 11 |
| 2 | `water_pollution` | Industrial runoff, contaminated waterways, lake waste | SDG 6, SDG 14 |
| 3 | `water_leakage` | Burst municipal water pipes, leaking mains, pooling water | SDG 6, SDG 11 |
| 4 | `streetlight_damage` | Broken street lamps, open junction boxes, dark public paths | SDG 7, SDG 11 |
| 5 | `infrastructure_damage` | Damaged sidewalks, broken guardrails, collapsing walls | SDG 9, SDG 11 |
| 6 | `tree_damage` | Fallen branches on power lines, uprooted trees, dead trunks | SDG 13, SDG 15 |
| 7 | `accessibility_issue` | Blocked wheelchair ramps, broken tactiles, sidewalk obstructions | SDG 10, SDG 11 |
| 8 | `air_pollution` | Open garbage burning, visible exhaust smog, localized smoke | SDG 3, SDG 11, SDG 13 |
| 9 | `public_safety` | Open manholes, missing storm covers, construction hazards | SDG 11, SDG 16 |

---

## 2. Directory Structure

Organize the dataset in YOLO format:

```text
dataset/
├── images/
│   ├── train/
│   │   ├── img001.jpg
│   │   └── ...
│   ├── val/
│   │   ├── img101.jpg
│   │   └── ...
│   └── test/
│       ├── img201.jpg
│       └── ...
└── labels/
    ├── train/
    │   ├── img001.txt
    │   └── ...
    ├── val/
    │   ├── img101.txt
    │   └── ...
    └── test/
        ├── img201.txt
        └── ...
```

### Recommended Split:
- **Train:** 70%
- **Validation:** 20%
- **Test:** 10%

---

## 3. Label Annotation Format

Each image corresponds to a `.txt` label file with normalized bounding coordinates `(0.0 to 1.0)`:

```text
<class_id> <x_center> <y_center> <width> <height>
```

Example (`labels/train/img001.txt`):
```text
0 0.452 0.612 0.340 0.420
1 0.720 0.810 0.150 0.120
```

---

## 4. Dataset Configuration YAML (`dataset/medal.yaml`)

Create `dataset/medal.yaml`:

```yaml
path: ../dataset # dataset root dir
train: images/train
val: images/val
test: images/test

names:
  0: waste_dumping
  1: road_damage
  2: water_pollution
  3: water_leakage
  4: streetlight_damage
  5: infrastructure_damage
  6: tree_damage
  7: accessibility_issue
  8: air_pollution
  9: public_safety
```

---

## 5. Training Command

Activate the backend virtual environment:

```powershell
cd E:\MEDAL\MEDAL-APP-main\backend
.\venv\Scripts\activate
```

Run training using Ultralytics CLI:

```bash
yolo detect train \
    model=models/yolo26n.pt \
    data=dataset/medal.yaml \
    epochs=100 \
    imgsz=640 \
    batch=16 \
    device=0 \
    project=runs/medal \
    name=medal_yolo26_v1
```

Or via Python:

```python
from ultralytics import YOLO

# Load base pretrained model
model = YOLO("models/yolo26n.pt")

# Fine-tune on MEDAL civic dataset
results = model.train(
    data="dataset/medal.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    device="0",  # Or 'cpu' if GPU is unavailable
    project="runs/medal",
    name="medal_yolo26_v1",
)
```

---

## 6. Model Evaluation and Validation

Evaluate model performance on the hold-out validation set:

```bash
yolo detect val \
    model=runs/medal/medal_yolo26_v1/weights/best.pt \
    data=dataset/medal.yaml
```

Metrics to record:
- **mAP@50**: Target $\ge 0.82$ across all civic categories
- **mAP@50-95**: Target $\ge 0.55$
- Precision and Recall per class

---

## 7. Model Deployment into MEDAL

Once training is verified:

1. Copy the best checkpoint weights:
   ```powershell
   copy runs\medal\medal_yolo26_v1\weights\best.pt models\medal_yolo26.pt
   ```

2. Update environment variable in `backend/.env`:
   ```env
   YOLO_MODEL_PATH=models/medal_yolo26.pt
   YOLO_CONFIDENCE_THRESHOLD=0.45
   ```

3. Restart backend service:
   The FastAPI lifespan automatically loads `models/medal_yolo26.pt` on startup.

4. Seamless compatibility:
   Because the MEDAL architecture encapsulates detection in `CivicIssueService`, the `CUSTOM_MEDAL_CLASSES` lookup activates automatically for any of the 10 custom classes. No changes to the Flutter client or database schemas are required.
