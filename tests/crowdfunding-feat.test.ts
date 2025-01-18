import { describe, it, beforeEach, expect } from 'vitest';

// Mock state and functions for the contract logic

let projectTags: any;
let projectProgress: any;
let projects: { [x: string]: any; 1?: { owner: string; title: string; }; 2?: { owner: string; title: string; }; };
let txSender: string;
const ERR_NOT_FOUND = 'err u404';
const ERR_UNAUTHORIZED = 'err u403';
const ERR_INVALID_PERCENTAGE = 'err u400';

// Mock function to initialize state before each test
beforeEach(() => {
  projectTags = {};
  projectProgress = {};
  projects = {
    1: { owner: 'user1', title: 'Project One' },
    2: { owner: 'user2', title: 'Project Two' },
  };
  txSender = 'user1';
});

const getProject = (projectId: string | number) => {
  return projects[projectId] || null;
};

const setProjectTags = (projectId: number, tags: string[]) => {
  const project = getProject(projectId);
  if (!project) throw new Error(ERR_NOT_FOUND);
  if (project.owner !== txSender) throw new Error(ERR_UNAUTHORIZED);

  projectTags[projectId] = tags;
  return true;
};

const updateProjectProgress = (projectId: number, percentage: number) => {
  const project = getProject(projectId);
  if (!project) throw new Error(ERR_NOT_FOUND);
  if (project.owner !== txSender) throw new Error(ERR_UNAUTHORIZED);
  if (percentage > 100) throw new Error(ERR_INVALID_PERCENTAGE);

  projectProgress[projectId] = {
    percentageComplete: percentage,
    lastUpdate: Date.now(),
  };
  return true;
};

describe('Project Tags Manager', () => {
  it('should set tags for a project successfully', () => {
    const result = setProjectTags(1, ['tag1', 'tag2']);
    expect(result).toBe(true);
    expect(projectTags[1]).toEqual(['tag1', 'tag2']);
  });

  it('should reject setting tags for non-existent project', () => {
    expect(() => setProjectTags(3, ['tag1'])).toThrow(ERR_NOT_FOUND);
  });

  it('should reject setting tags by unauthorized user', () => {
    txSender = 'user2';
    expect(() => setProjectTags(1, ['tag1'])).toThrow(ERR_UNAUTHORIZED);
  });
});

describe('Project Progress Manager', () => {
  it('should update progress successfully', () => {
    const result = updateProjectProgress(1, 50);
    expect(result).toBe(true);
    expect(projectProgress[1]).toMatchObject({
      percentageComplete: 50,
    });
  });

  it('should reject progress update for non-existent project', () => {
    expect(() => updateProjectProgress(3, 50)).toThrow(ERR_NOT_FOUND);
  });

  it('should reject progress update by unauthorized user', () => {
    txSender = 'user2';
    expect(() => updateProjectProgress(1, 50)).toThrow(ERR_UNAUTHORIZED);
  });

  it('should reject progress update with invalid percentage', () => {
    expect(() => updateProjectProgress(1, 150)).toThrow(ERR_INVALID_PERCENTAGE);
  });
});
