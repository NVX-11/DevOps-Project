from flask import Flask, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics
import logging
import os

app = Flask(__name__)
metrics = PrometheusMetrics(app)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

tasks = [
    {"id": 1, "title": "Buy groceries", "description": "Milk, eggs, bread", "done": False},
    {"id": 2, "title": "Complete report", "description": "Q4 financial summary", "done": False},
    {"id": 3, "title": "Team meeting", "description": "Project sync at 3 PM", "done": True}
]

@app.route('/health')
def health():
    logger.info("Health check called")
    return jsonify({"status": "healthy", "service": "task-service"}), 200

@app.route('/ready')
def ready():
    return jsonify({"status": "ready"}), 200

@app.route('/tasks', methods=['GET'])
def get_tasks():
    logger.info(f"Fetching all tasks - total: {len(tasks)}")
    return jsonify({"tasks": tasks, "count": len(tasks)}), 200

@app.route('/tasks/<int:task_id>', methods=['GET'])
def get_task(task_id):
    task = next((t for t in tasks if t['id'] == task_id), None)
    if task:
        logger.info(f"Task {task_id} found")
        return jsonify(task), 200
    logger.warning(f"Task {task_id} not found")
    return jsonify({"error": "Task not found"}), 404

@app.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({"error": "Title is required"}), 400

    new_task = {
        "id": max([t['id'] for t in tasks], default=0) + 1,
        "title": data['title'],
        "description": data.get('description', ''),
        "done": data.get('done', False)
    }
    tasks.append(new_task)
    logger.info(f"Task created: {new_task['id']} - {new_task['title']}")
    return jsonify(new_task), 201

@app.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    task = next((t for t in tasks if t['id'] == task_id), None)
    if not task:
        return jsonify({"error": "Task not found"}), 404

    data = request.get_json()
    task['title'] = data.get('title', task['title'])
    task['description'] = data.get('description', task['description'])
    task['done'] = data.get('done', task['done'])

    logger.info(f"Task updated: {task_id}")
    return jsonify(task), 200

@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    global tasks
    task = next((t for t in tasks if t['id'] == task_id), None)
    if not task:
        return jsonify({"error": "Task not found"}), 404

    tasks = [t for t in tasks if t['id'] != task_id]
    logger.info(f"Task deleted: {task_id}")
    return jsonify({"message": "Task deleted"}), 200

@app.route('/')
def index():
    return jsonify({
        "service": "task-service",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "tasks": "/tasks",
            "metrics": "/metrics"
        }
    }), 200

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    logger.info(f"Starting Task Service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
