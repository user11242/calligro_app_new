import React from 'react';
import './index.css';
import { Composition } from 'remotion';
import { Intro } from './Intro';

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="CalligroIntro"
      component={Intro}
      durationInFrames={3900}
      fps={30}
      width={1080}
      height={1920}
    />
  </>
);
