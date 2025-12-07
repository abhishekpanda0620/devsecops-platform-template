/**
 * User Routes
 * CRUD operations for user management
 */

const express = require('express');
const { body, param, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// In-memory storage (replace with database in production)
const users = new Map();

// Validation middleware
const handleValidationErrors = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }
    next();
};

// Validation rules
const userValidation = [
    body('email')
        .isEmail()
        .normalizeEmail()
        .withMessage('Valid email is required'),
    body('name')
        .trim()
        .isLength({ min: 2, max: 100 })
        .withMessage('Name must be between 2 and 100 characters'),
    body('role')
        .optional()
        .isIn(['user', 'admin', 'moderator'])
        .withMessage('Role must be user, admin, or moderator')
];

/**
 * GET /api/users
 * List all users
 */
router.get('/', (req, res) => {
    const userList = Array.from(users.values());
    res.json({
        count: userList.length,
        users: userList
    });
});

/**
 * GET /api/users/:id
 * Get user by ID
 */
router.get('/:id',
    param('id').isUUID().withMessage('Invalid user ID'),
    handleValidationErrors,
    (req, res) => {
        const user = users.get(req.params.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json(user);
    }
);

/**
 * POST /api/users
 * Create a new user
 */
router.post('/',
    userValidation,
    handleValidationErrors,
    (req, res) => {
        const { email, name, role = 'user' } = req.body;

        // Check for duplicate email
        const existingUser = Array.from(users.values()).find(u => u.email === email);
        if (existingUser) {
            return res.status(409).json({ error: 'Email already exists' });
        }

        const newUser = {
            id: uuidv4(),
            email,
            name,
            role,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };

        users.set(newUser.id, newUser);
        res.status(201).json(newUser);
    }
);

/**
 * PUT /api/users/:id
 * Update an existing user
 */
router.put('/:id',
    param('id').isUUID().withMessage('Invalid user ID'),
    userValidation,
    handleValidationErrors,
    (req, res) => {
        const user = users.get(req.params.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const { email, name, role } = req.body;

        // Check for duplicate email (excluding current user)
        const existingUser = Array.from(users.values()).find(
            u => u.email === email && u.id !== req.params.id
        );
        if (existingUser) {
            return res.status(409).json({ error: 'Email already exists' });
        }

        const updatedUser = {
            ...user,
            email,
            name,
            role: role || user.role,
            updatedAt: new Date().toISOString()
        };

        users.set(req.params.id, updatedUser);
        res.json(updatedUser);
    }
);

/**
 * DELETE /api/users/:id
 * Delete a user
 */
router.delete('/:id',
    param('id').isUUID().withMessage('Invalid user ID'),
    handleValidationErrors,
    (req, res) => {
        const user = users.get(req.params.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        users.delete(req.params.id);
        res.status(204).send();
    }
);

module.exports = router;
