import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

@Injectable()
export class DatabaseService {
    private pool = new Pool({
        host: 'localhost',
        port: 5432,
        user: 'postgres',
        password: 'postgres',
        database: 'fmdb',
    });

    async query(text: string, params?: any[]) {
        return this.pool.query(text, params);
    }
}
