const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');

const app = express();
app.use(express.json());

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.Console()
    ]
});

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestCounter = new promClient.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [register]
});

let users = [
    { id: 1, name: "Alice Johnson", email: "alice@company.com", role: "Developer" },
    { id: 2, name: "Bob Smith", email: "bob@company.com", role: "DevOps Engineer" },
    { id: 3, name: "Charlie Brown", email: "charlie@company.com", role: "Manager" }
];

app.use((req, res, next) => {
    res.on('finish', () => {
        httpRequestCounter.labels(req.method, req.route?.path || req.path, res.statusCode).inc();
    });
    next();
});

app.get('/health', (req, res) => {
    logger.info('Health check called');
    res.json({ status: 'healthy', service: 'user-service' });
});

app.get('/ready', (req, res) => {
    res.json({ status: 'ready' });
});

app.get('/users', (req, res) => {
    logger.info(`Fetching all users - total: ${users.length}`);
    res.json({ users, count: users.length });
});

app.get('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const user = users.find(u => u.id === id);

    if (user) {
        logger.info(`User ${id} found`);
        res.json(user);
    } else {
        logger.warn(`User ${id} not found`);
        res.status(404).json({ error: 'User not found' });
    }
});

app.post('/users', (req, res) => {
    const { name, email, role } = req.body;

    if (!name || !email) {
        return res.status(400).json({ error: 'Name and email are required' });
    }

    const newUser = {
        id: Math.max(...users.map(u => u.id), 0) + 1,
        name,
        email,
        role: role || 'User'
    };

    users.push(newUser);
    logger.info(`User created: ${newUser.id} - ${newUser.name}`);
    res.status(201).json(newUser);
});

app.put('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const user = users.find(u => u.id === id);

    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }

    user.name = req.body.name || user.name;
    user.email = req.body.email || user.email;
    user.role = req.body.role || user.role;

    logger.info(`User updated: ${id}`);
    res.json(user);
});

app.delete('/users/:id', (req, res) => {
    const id = parseInt(req.params.id);
    const userIndex = users.findIndex(u => u.id === id);

    if (userIndex === -1) {
        return res.status(404).json({ error: 'User not found' });
    }

    users.splice(userIndex, 1);
    logger.info(`User deleted: ${id}`);
    res.json({ message: 'User deleted' });
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

app.get('/', (req, res) => {
    res.json({
        service: 'user-service',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            users: '/users',
            metrics: '/metrics'
        }
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    logger.info(`User Service listening on port ${PORT}`);
});
