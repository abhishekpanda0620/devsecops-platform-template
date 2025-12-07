/**
 * API Integration Tests
 * Tests for the User Service endpoints
 */

const request = require('supertest');
const app = require('../src/index');

describe('User Service API', () => {
    let createdUserId;

    describe('GET /', () => {
        it('should return service info', async () => {
            const res = await request(app).get('/');
            expect(res.status).toBe(200);
            expect(res.body.service).toBe('user-service');
            expect(res.body.status).toBe('running');
        });
    });

    describe('Health Endpoints', () => {
        it('GET /health should return healthy status', async () => {
            const res = await request(app).get('/health');
            expect(res.status).toBe(200);
            expect(res.body.status).toBe('healthy');
        });

        it('GET /health/live should return alive status', async () => {
            const res = await request(app).get('/health/live');
            expect(res.status).toBe(200);
            expect(res.body.status).toBe('alive');
        });

        it('GET /health/ready should return ready status', async () => {
            const res = await request(app).get('/health/ready');
            expect(res.status).toBe(200);
            expect(res.body.status).toBe('ready');
        });

        it('GET /health/metrics should return metrics', async () => {
            const res = await request(app).get('/health/metrics');
            expect(res.status).toBe(200);
            expect(res.body).toHaveProperty('uptime');
            expect(res.body).toHaveProperty('memory');
        });
    });

    describe('User CRUD Operations', () => {
        describe('POST /api/users', () => {
            it('should create a new user', async () => {
                const newUser = {
                    email: 'test@example.com',
                    name: 'Test User',
                    role: 'user'
                };

                const res = await request(app)
                    .post('/api/users')
                    .send(newUser);

                expect(res.status).toBe(201);
                expect(res.body.email).toBe(newUser.email);
                expect(res.body.name).toBe(newUser.name);
                expect(res.body).toHaveProperty('id');
                createdUserId = res.body.id;
            });

            it('should reject duplicate email', async () => {
                const duplicateUser = {
                    email: 'test@example.com',
                    name: 'Another User'
                };

                const res = await request(app)
                    .post('/api/users')
                    .send(duplicateUser);

                expect(res.status).toBe(409);
                expect(res.body.error).toBe('Email already exists');
            });

            it('should validate email format', async () => {
                const invalidUser = {
                    email: 'invalid-email',
                    name: 'Test User'
                };

                const res = await request(app)
                    .post('/api/users')
                    .send(invalidUser);

                expect(res.status).toBe(400);
                expect(res.body.errors).toBeDefined();
            });

            it('should validate name length', async () => {
                const invalidUser = {
                    email: 'valid@example.com',
                    name: 'A' // Too short
                };

                const res = await request(app)
                    .post('/api/users')
                    .send(invalidUser);

                expect(res.status).toBe(400);
            });
        });

        describe('GET /api/users', () => {
            it('should list all users', async () => {
                const res = await request(app).get('/api/users');
                expect(res.status).toBe(200);
                expect(res.body).toHaveProperty('count');
                expect(res.body).toHaveProperty('users');
                expect(Array.isArray(res.body.users)).toBe(true);
            });
        });

        describe('GET /api/users/:id', () => {
            it('should get user by ID', async () => {
                const res = await request(app).get(`/api/users/${createdUserId}`);
                expect(res.status).toBe(200);
                expect(res.body.id).toBe(createdUserId);
            });

            it('should return 404 for non-existent user', async () => {
                const res = await request(app).get('/api/users/00000000-0000-0000-0000-000000000000');
                expect(res.status).toBe(404);
            });

            it('should validate UUID format', async () => {
                const res = await request(app).get('/api/users/invalid-id');
                expect(res.status).toBe(400);
            });
        });

        describe('PUT /api/users/:id', () => {
            it('should update an existing user', async () => {
                const updatedData = {
                    email: 'updated@example.com',
                    name: 'Updated User',
                    role: 'admin'
                };

                const res = await request(app)
                    .put(`/api/users/${createdUserId}`)
                    .send(updatedData);

                expect(res.status).toBe(200);
                expect(res.body.email).toBe(updatedData.email);
                expect(res.body.role).toBe('admin');
            });

            it('should return 404 for non-existent user', async () => {
                const res = await request(app)
                    .put('/api/users/00000000-0000-0000-0000-000000000000')
                    .send({ email: 'test@example.com', name: 'Test' });

                expect(res.status).toBe(404);
            });
        });

        describe('DELETE /api/users/:id', () => {
            it('should delete an existing user', async () => {
                const res = await request(app).delete(`/api/users/${createdUserId}`);
                expect(res.status).toBe(204);
            });

            it('should return 404 for non-existent user', async () => {
                const res = await request(app).delete(`/api/users/${createdUserId}`);
                expect(res.status).toBe(404);
            });
        });
    });

    describe('Error Handling', () => {
        it('should return 404 for unknown routes', async () => {
            const res = await request(app).get('/unknown-route');
            expect(res.status).toBe(404);
            expect(res.body.error).toBe('Not Found');
        });
    });
});
