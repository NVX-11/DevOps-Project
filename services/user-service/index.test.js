const request = require('supertest');
const express = require('express');

jest.mock('winston', () => ({
    createLogger: jest.fn(() => ({
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn()
    })),
    format: {
        combine: jest.fn(),
        timestamp: jest.fn(),
        json: jest.fn()
    },
    transports: {
        Console: jest.fn()
    }
}));

const app = require('./index');

describe('User Service API', () => {
    test('GET /health returns healthy status', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    test('GET /users returns list of users', async () => {
        const response = await request(app).get('/users');
        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('users');
        expect(response.body).toHaveProperty('count');
    });

    test('POST /users creates a new user', async () => {
        const newUser = {
            name: 'Test User',
            email: 'test@example.com',
            role: 'Tester'
        };
        const response = await request(app).post('/users').send(newUser);
        expect(response.status).toBe(201);
        expect(response.body.name).toBe('Test User');
    });

    test('GET /users/:id returns a specific user', async () => {
        const response = await request(app).get('/users/1');
        expect(response.status).toBe(200);
        expect(response.body.id).toBe(1);
    });

    test('GET /users/:id returns 404 for non-existent user', async () => {
        const response = await request(app).get('/users/9999');
        expect(response.status).toBe(404);
    });
});
