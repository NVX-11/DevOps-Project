import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'

def test_get_tasks(client):
    response = client.get('/tasks')
    assert response.status_code == 200
    assert 'tasks' in response.json
    assert 'count' in response.json

def test_create_task(client):
    response = client.post('/tasks', json={
        'title': 'Test Task',
        'description': 'Test Description'
    })
    assert response.status_code == 201
    assert response.json['title'] == 'Test Task'

def test_get_task(client):
    response = client.get('/tasks/1')
    assert response.status_code == 200
    assert response.json['id'] == 1

def test_get_nonexistent_task(client):
    response = client.get('/tasks/9999')
    assert response.status_code == 404
